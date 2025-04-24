module PagesHelper
  def active_menu_item?(data)
    current_page?(data[:path]) || data[:subitems].any? do |subitem|
      current_page?(subitem_path(data[:path].to_s.split("_").first, subitem))
    end
  end

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
        path: "#",
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

  def active_class?(paths)
    paths.any? { |path| current_page?("#{locale_prefix}#{path}") || current_page?(path) } ? "text-amber-400" : "text-[#A0A0A0]"
  end

  def subitem_path(parent, item)
    case [ parent, item ]
    # Информация
    when [ t("pages.info_page.title"), t("pages.info_page.wiki.title") ] then "#"
    when [ t("pages.info_page.title"), t("pages.info_page.rules.title") ] then "#"
    when [ t("pages.info_page.title"), t("pages.info_page.how_start_to_play.title") ] then "#"
    when [ t("pages.info_page.title"), t("pages.info_page.faq.title") ] then "#"
    when [ t("pages.info_page.title"), t("pages.info_page.mods.title") ] then "#"

    # Экономика
    when [ t("pages.economy_page.title"), t("pages.economy_page.balance.title") ] then "#"
    when [ t("pages.economy_page.title"), t("pages.economy_page.mara_rate.title") ] then "#"
    when [ t("pages.economy_page.title"), t("pages.economy_page.tops.title") ] then "#"

    # Сообщество
    when [ t("pages.community_page.title"), t("pages.community_page.community.title") ] then "#"
    when [ t("pages.community_page.title"), t("pages.community_page.events.title") ] then "#"
    when [ t("pages.community_page.title"), t("pages.community_page.clans.title") ] then "#"
    when [ t("pages.community_page.title"), t("pages.community_page.photogallery.title") ] then "#"

    else
      "#"
    end
  end

  def locale_prefix
    I18n.locale.to_s == I18n.default_locale.to_s ? "" : "/#{I18n.locale}"
  end
end
