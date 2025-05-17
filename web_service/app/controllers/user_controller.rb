class UserController < ApplicationController
  def show
    require_login
  end

  private

  def require_login
    unless current_user
      redirect_to login_path, alert: t("controllers.auth.unauthorized")
    end
  end
end
