module Api
  module V1
    class GalleryController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_service_request

      before_action :is_admin?, only: [ :create, :update ]

      def index
        begin
          search     = params[:search].to_s.strip.downcase
          allowed_sorts = %w[title created_at]
          sort_key   = allowed_sorts.include?(params[:sort]) ? params[:sort] : 'created_at'
          order_dir  = %w[asc desc].include?(params[:order]) ? params[:order] : 'desc'
          page       = (params[:page] || 1).to_i.clamp(1, 10_000)
          per_page   = (params[:per_page] || 25).to_i.clamp(1, 100)

          # Используем includes(:photos), чтобы загрузить фото сразу (избегаем N+1)
          galleries = Gallery.includes(:photos).all

          # Поиск по названию
          if search.present?
            galleries = galleries.where("LOWER(title) LIKE ?", "%#{search}%")
          end

          # Фильтрация по статусу
          if params[:published].present?
            galleries = galleries.where(published: ActiveModel::Type::Boolean.new.cast(params[:published]))
          end

          # Сортировка
          galleries = galleries.order(Arel.sql("#{sort_key} #{order_dir}"))

          # Пагинация
          total_count = galleries.count
          galleries   = galleries.offset((page - 1) * per_page).limit(per_page)

          # Форматирование ответа
          formatted = galleries.map do |gallery|
            # Берем первое фото для обложки
            cover_photo = gallery.photos.first
            
            {
              id: gallery.id,
              title: gallery.title,
              description: gallery.description,
              published: gallery.published,
              photos_count: gallery.photos.size,
              created_at: gallery.created_at,
              # ВАЖНО: Генерируем абсолютный URL, чтобы фронтенд мог загрузить картинку с правильного порта (3002)
              cover_url: if cover_photo&.file&.attached?
                           rails_blob_url(cover_photo.file, host: request.base_url)
                         else
                           nil
                         end
            }
          end

          render json: {
            galleries: formatted,
            total_count: total_count
          }

        rescue => e
          Rails.logger.error "Ошибка при получении галерей: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: "Ошибка загрузки галерей", details: e.message }, status: :internal_server_error
        end
      end

      def show
        begin
          @gallery = Gallery.includes(:photos).find(params[:id])

          # Форматируем ответ
          gallery_data = {
            id: @gallery.id,
            title: @gallery.title,
            description: @gallery.description,
            published: @gallery.published,
            created_at: @gallery.created_at,
            updated_at: @gallery.updated_at,
            photos_count: @gallery.photos.size,
            photos: @gallery.photos.map do |photo|
              {
                id: photo.id,
                title: photo.title,
                file_url: rails_blob_url(photo.file, host: request.base_url),
                created_at: photo.created_at,
                updated_at: photo.updated_at
              }
            end
          }

          render json: gallery_data, status: :ok
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Gallery not found" }, status: :not_found
        rescue => e
          Rails.logger.error "Error showing gallery: #{e.message}"
          render json: { error: "Internal server error", details: e.message }, status: :internal_server_error
        end
      end

      def create
        begin
          # Проверяем наличие обязательных параметров
          unless params[:gallery].present?
            return render json: { errors: ["Gallery parameters are missing"] }, status: :unprocessable_entity
          end

          @gallery = Gallery.new(gallery_params)

          # Проверяем, что если галерея публикуется, то в параметрах есть фотографии
          if @gallery.published? && params[:gallery][:photos_attributes].blank?
            return render json: { errors: ["Published cannot be published without photos"] }, status: :unprocessable_entity
          end

          if @gallery.save
            render json: { status: "ok", id: @gallery.id }, status: :ok
          else
            render json: { errors: @gallery.errors.full_messages }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "Error creating gallery: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: "Internal server error", details: e.message }, status: :internal_server_error
        end
      end

      def destroy
        @gallery = Gallery.find(params[:id])

        if @gallery.destroy
          render json: { status: "ok", id: @gallery.id }, status: :ok
        else
          render json: { errors: @gallery.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Gallery not found" }, status: :not_found
      rescue => e
        Rails.logger.error "Error destroying gallery: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: "Internal server error" }, status: :internal_server_error
      end

      def update
        begin
          @gallery = Gallery.find(params[:id])
          if @gallery.update(gallery_params)
            render json: { status: "ok", id: @gallery.id }, status: :ok
          else
            render json: { errors: @gallery.errors.full_messages }, status: :unprocessable_entity
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Gallery not found" }, status: :not_found
        rescue => e
          Rails.logger.error "Error updating gallery: #{e.message}"
          render json: { error: "Internal server error", details: e.message }, status: :internal_server_error
        end
      end

      private

      def gallery_params
        params.require(:gallery).permit(
          :title,
          :description,
          :published,
          photos_attributes: [ :id, :title, :file, :_destroy ]
        )
      end
    end
  end
end
