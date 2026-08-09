module Api
  module V1
    class DiscordAvatarController < ApplicationController
      before_action :authenticate
      before_action :set_discord_avatar, only: [:show, :update, :destroy]
      before_action :check_ownership, only: [:update, :destroy]
      before_action :authenticate_admin, only: [:admin_index, :approve, :reject]
      before_action :set_avatar_by_id, only: [:approve, :reject]
      before_action :validate_file_presence, only: [:create, :update]

      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_service_request

      # Получение аватаров текущего пользователя
      def index
        @avatars = DiscordAvatar.where(discord_account_id: current_user.discord_account.id)
        render json: @avatars.map { |avatar| avatar_json(avatar) }
      end

      # Получение аватара по ID
      def show
        render json: avatar_json(@avatar)
      end

      # Создание нового аватара
      def create
        # Удаляем ожидающий аватар, если он есть
        pending_avatar = DiscordAvatar.find_by(
          discord_account_id: current_user.discord_account.id,
          status: 'pending'
        )
        
        if pending_avatar
          pending_avatar.file.purge if pending_avatar.file.attached?
          pending_avatar.destroy
        end

        # Создаем новый аватар
        @avatar = DiscordAvatar.new(discord_avatar_params)
        @avatar.discord_account = current_user.discord_account

        if @avatar.save
          render json: avatar_json(@avatar), status: :created
        else
          render json: { errors: @avatar.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # Обновление аватара
      def update
        if @avatar.update(discord_avatar_params)
          render json: avatar_json(@avatar)
        else
          render json: { errors: @avatar.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # Удаление аватара
      def destroy
        # Если удаляем одобренный аватар, очищаем поле avatar в DiscordAccount
        if @avatar.status == 'approved' && @avatar.discord_account.avatar.present?
          @avatar.discord_account.update(avatar: nil)
        end
        
        # Удаляем файл и саму запись
        @avatar.file.purge if @avatar.file.attached?
        @avatar.destroy
        
        head :no_content
      end

      # Получение всех аватаров для администратора с фильтрацией, сортировкой и пагинацией
      def admin_index
        # Базовый запрос с включением связанных моделей
        query = DiscordAvatar.includes(discord_account: :user).all

        # Фильтрация по статусу
        query = query.where(status: params[:status]) if params[:status].present?

        # Фильтрация по дате создания
        if params[:from].present?
          from_date = DateTime.parse(params[:from])
          query = query.where('discord_avatars.created_at >= ?', from_date)
        end

        if params[:to].present?
          to_date = DateTime.parse(params[:to]).end_of_day
          query = query.where('discord_avatars.created_at <= ?', to_date)
        end

        # Поиск по имени пользователя
        if params[:user_name].present?
          query = query.joins(discord_account: :user)
                   .where('users.username ILIKE ?', "%#{params[:user_name]}%")
        end

        # Сортировка
        sort_by = params[:sort_by] || 'created_at'
        sort_order = params[:sort_order] || 'desc'
        
        # Обработка сортировки по имени пользователя
        if sort_by == 'user_name'
          query = query.joins(discord_account: :user)
                   .order("users.username #{sort_order}")
        else
          query = query.order("discord_avatars.#{sort_by} #{sort_order}")
        end

        # Пагинация
        page = params[:page] || 1
        per = params[:per] || 50
        
        total_count = query.count
        avatars = query.limit(per).offset((page.to_i - 1) * per.to_i)

        # Формируем ответ с пагинацией
        render json: {
          avatars: avatars.map { |avatar| admin_avatar_json(avatar) },
          pagination: {
            total: total_count,
            page: page.to_i,
            per: per.to_i,
            pages: (total_count / per.to_f).ceil
          }
        }
      end

      # Одобрение аватара
      def approve
        # Находим и удаляем предыдущий одобренный аватар, если он есть
        previous_approved = DiscordAvatar.find_by(
          discord_account_id: @avatar.discord_account_id,
          status: 'approved'
        )
        
        if previous_approved
          # Удаляем файл предыдущего аватара
          previous_approved.file.purge if previous_approved.file.attached?
          previous_approved.destroy
        end

        # Обновляем статус текущего аватара на одобренный
        if @avatar.update(status: 'approved')
          # Генерируем правильный URL для аватара
          avatar_url = generate_avatar_url(@avatar)
          
          # Обновляем аватар в DiscordAccount с правильным URL
          @avatar.discord_account.update(avatar: avatar_url)
          
          render json: avatar_json(@avatar)
        else
          render json: { errors: @avatar.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # Отклонение аватара
      def reject
        # Обновляем статус текущего аватара на отклоненный
        if @avatar.update(status: 'rejected')
          render json: avatar_json(@avatar)
        else
          render json: { errors: @avatar.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      # Генерация правильного URL для аватара
      def generate_avatar_url(avatar)
        if avatar.file.attached?
          host_uri = URI.parse(ENV["AUTH_SERVICE_URL"])
          rails_blob_url(avatar.file, host: host_uri.host, protocol: host_uri.scheme)
        else
          nil
        end
      end

      # Аутентификация пользователя
      def authenticate
        user_id = request.headers['X-User-ID'] || params[:user_id]

        unless user_id.present?
          render json: { error: 'User ID is required' }, status: :unprocessable_entity and return
        end

        @current_user = User.find_by(id: user_id)
        unless @current_user
          render json: { error: 'User not found' }, status: :not_found and return
        end
      end

      # Проверка прав администратора
      def authenticate_admin
        unless [ 3, 4 ].include?(current_user&.role_id)
          render json: { error: 'Admin access required' }, status: :forbidden and return
        end
      end

      # Получение текущего пользователя
      def current_user
        @current_user
      end

      # Установка аватара по ID
      def set_avatar_by_id
        @avatar = DiscordAvatar.find_by(id: params[:id])

        unless @avatar
          render json: { error: 'Avatar not found' }, status: :not_found and return
        end
      end

      # Установка аватара для текущего пользователя
      def set_discord_avatar
        user_id = params[:user_id]

        unless user_id.present?
          render json: { error: 'User ID is required' }, status: :unprocessable_entity
          return
        end

        user = User.find_by(id: user_id)
        unless user&.discord_account
          render json: { error: 'Discord account not found' }, status: :not_found
          return
        end

        avatars = DiscordAvatar.where(discord_account_id: user.discord_account.id)

        if avatars.empty?
          render json: { error: 'Avatar not found' }, status: :not_found
          return
        end

        @avatar = avatars.find_by(status: 'pending') || avatars.first
      rescue => e
        Rails.logger.error("Error in set_discord_avatar: #{e.message}")
        render json: { error: 'Internal server error' }, status: :internal_server_error
      end

      # Проверка прав владения
      def check_ownership
        return if @avatar.discord_account.user == current_user

        render json: { error: 'Not authorized' }, status: :forbidden and return
      end

      # Проверка наличия файла
      def validate_file_presence
        return if params[:avatar].present? && params[:avatar].respond_to?(:tempfile)

        render json: { error: 'File is required' }, status: :unprocessable_entity and return
      end

      def normalize_domain(url)
        return nil unless url.present?

        auth_service_url = ENV['AUTH_SERVICE_URL']
        unless auth_service_url.present?
          Rails.logger.warn "AUTH_SERVICE_URL is not set, cannot normalize domain"
          return url
        end

        expected_uri = URI.parse(auth_service_url)

        uri = URI.parse(url)

        if uri.host == expected_uri.host && uri.port == expected_uri.port
          return url
        end

        uri.host = expected_uri.host
        uri.port = expected_uri.port
        uri.scheme = expected_uri.scheme

        uri.to_s
      rescue URI::InvalidURIError
        Rails.logger.warn "Invalid URL detected: #{url}"
        nil
      end

      # Параметры для создания/обновления аватара
      def discord_avatar_params
        {
          file: params[:avatar],
          status: 'pending',
          original_url: params[:original_url]
        }
      end

      # Форматирование JSON для аватара
      def avatar_json(avatar)
        {
          id: avatar.id,
          status: avatar.status,
          url: avatar.file.attached? ? normalize_domain(rails_blob_url(avatar.file, host: ENV["AUTH_SERVICE_URL"])) : nil,
          original_url: normalize_domain(avatar.original_url),
          created_at: avatar.created_at,
          updated_at: avatar.updated_at
        }
      end

      # Расширенное форматирование JSON для администратора
      def admin_avatar_json(avatar)
        {
          id: avatar.id,
          status: avatar.status,
          url: avatar.file.attached? ? normalize_domain(rails_blob_url(avatar.file, host: ENV["AUTH_SERVICE_URL"])) : nil,
          original_url: normalize_domain(avatar.original_url),
          created_at: avatar.created_at,
          updated_at: avatar.updated_at,
          user: {
            id: DiscordAccount.find(avatar.discord_account_id).user_id,
            username: User.find(DiscordAccount.find(avatar.discord_account_id).user_id).minecraft_account_data["nickname"]
          }
        }
      end
    end
  end
end
