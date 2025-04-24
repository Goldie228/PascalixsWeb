class UserController < ApplicationController
  include AuthServiceData
  
  before_action :require_login
  before_action :load_user_data

  def show
    # Представление использует @user_data, загруженные из AuthServiceData
    # Дополнительная логика представления пользователя
  end

  private

  def require_login
    unless current_user
      redirect_to login_path, alert: t('controllers.auth.unauthorized')
    end
  end
end 