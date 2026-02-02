
module Api
  module V1
    module Wiki
      class BaseController < ApplicationController # Наследуемся от твоего базового API контроллера
        
        # Для всех действий, кроме index и show, требуем права администратора
        before_action :require_admin!, except: [:index, :show]
        skip_before_action :verify_authenticity_token

        private

        def require_admin!
          unless is_admin?
            render json: { error: I18n.t('controllers.wiki.access_denied') }, status: :forbidden
          end
        end

        def render_error(message, status = :unprocessable_entity)
          render json: { error: message }, status: status
        end

        def render_not_found
          render json: { error: I18n.t('controllers.wiki.not_found') }, status: :not_found
        end

        # Безопасная загрузка картинок (проверка типа)
        def attach_image(record, file_param)
          return unless file_param.present?

          unless file_param.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
            record.errors.add(:images, 'неверный формат файла (допустимы: jpeg, png, gif, webp)')
            return false
          end
          
          record.images.attach(file_param)
          true
        rescue ActiveRecord::RecordInvalid
          false
        end
      end
    end
  end
end
