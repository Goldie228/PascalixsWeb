class UserController < ApplicationController
  def show
    require_login

    @mc_roles = {
      "Владелец" => "#F5B202",
      "Администратор" => "#ED1818",
      "Губернатор" => "#DA2F8A",
      "ЭСБР" => "#2727D3",
      "Судья" => "#03C487",
      "Полиция" => "#01B4F5",
      "Гражданин" => "#989898"
    }

    @web_role = current_user.role_name
    @web_role_color = current_user.role_color

    # 100.times do |i|
    #   @mc_roles["Гражданин#{i + 1}"] = "#989898"
    # end
  end

  private

  def require_login
    unless current_user
      redirect_to login_path, alert: t("controllers.auth.unauthorized")
    end
  end
end
