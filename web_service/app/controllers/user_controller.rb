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

    # Роли: User => #A0A0A0, Player => #22C55E, DEV => #EF4444, OWNER => #F59E0B

    # @web_role = ""
    # @web_role_color = ""

    # @web_role = "User"
    # @web_role_color = "#A0A0A0"

    @web_role = "Player"
    @web_role_color = "#EDEDED"

    # @web_role = "DEV"
    # @web_role_color = "#EF4444"

    # @web_role = "OWNER"
    # @web_role_color = "#F59E0B"

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
