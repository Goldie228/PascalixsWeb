module ApplicationHelper
  def active_class(path)
    request.path.start_with?(path) ? "active" : ""
  end

  # Метод для получения структуры меню для шаблона navbar
  def menu_structure
    {
      t("pages.home_page.title") => { path: localized_root_path, subitems: [] },
      t("pages.info_page.title") => {
        path: "#",
        subitems: [
          t("pages.info_page.wiki.title"),
          t("pages.info_page.rules.title"),
          t("pages.info_page.how_start_to_play.title"),
          t("pages.info_page.faq.title"),
          t("pages.info_page.mods.title")
        ]
      },
      t("pages.economy_page.title") => {
        path: "#",
        subitems: [
          t("pages.economy_page.balance.title"),
          t("pages.economy_page.mara_rate.title"),
          t("pages.economy_page.tops.title")
        ]
      },
      t("pages.community_page.title") => {
        path: players_path,
        subitems: [
          t("pages.community_page.community.title"),
          t("pages.community_page.events.title"),
          t("pages.community_page.clans.title"),
          t("pages.community_page.photogallery.title")
        ]
      },
      t("pages.donate_page.title") => { path: "#", subitems: [] },
      t("pages.map_page.title") => { path: "#", subitems: [] }
    }
  end

  # Метод для генерации пути к подпункту меню
  def subitem_path(main_item, subitem)
    # Заглушка для путей подпунктов меню
    # Здесь должна быть логика построения путей
    "#"
  end

  # Метод для получения аватара пользователя
  def user_avatar(user, size = "small")
    if user&.discord_account&.avatar.present?
      user.discord_account.avatar
    else
      # Стандартный аватар, если у пользователя нет своего
      "default_avatar_#{size}.png"
    end
  end

  # Форматирование времени с учетом часового пояса
  def format_time(time, format = :default)
    return "" unless time
    time.in_time_zone(Time.zone).strftime(t("time.formats.#{format}"))
  end

  def asset_exist?(path)
    if Rails.env.development?
      Rails.application.assets&.find_asset(path).present?
    else
      Rails.application.assets_manifest&.assets&.key?(path)
    end
  rescue => e
    Rails.logger.error "Error checking asset existence: #{e.message}"
    false
  end

  def role_name_by_id(role_id)
  {
    1 => "User",
    2 => "Player",
    3 => "DEV",
    4 => "OWNER"
  }[role_id.to_i] || "Unknown"
  end

  def role_color_by_id(role_id)
    {
      1 => "#A0A0A0",
      2 => "#22C55E",
      3 => "#3B82F6",
      4 => "#FF0066"
    }[role_id.to_i] || "#666666"
  end
end
