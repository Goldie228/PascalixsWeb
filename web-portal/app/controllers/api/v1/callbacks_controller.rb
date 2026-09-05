module Api
  module V1
    class CallbacksController < ActionController::API
      before_action :authenticate_service

      # Метод для обработки событий аутентификации от auth_service
      def auth_event
        user_data = params.require(:user).permit(:id, :email, :username, :is_registered)
        
        # Здесь можно обработать полученные данные
        # Например, обновить сессию пользователя или отправить уведомление

        render json: { status: 'success' }, status: :ok
      end

      private

      def authenticate_service
        # Простая проверка API-ключа
        api_key = request.headers['X-API-KEY']
        
        unless api_key.present? && api_key == ENV['INTER_SERVICE_API_KEY']
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end 