class AdminController < ApplicationController
  before_action :is_admin?, :update_users_data

  def players
    filters   = Array(params[:filters])
    per_page  = (params[:per_page] || 25).to_i.clamp(1, 100)
    page      = (params[:page] || 1).to_i.clamp(1, 10_000)
    order     = %w[asc desc].include?(params[:order]) ? params[:order] : "asc"
    sort      = %w[minecraft_nickname discord_username punishment_status is_added].include?(params[:sort]) ? params[:sort] : "minecraft_nickname"
    search    = params[:search].to_s.strip.downcase
    offset    = (page - 1) * per_page

    filter_map = {
      "pass"   => { column: "is_added", values: [ 1 ] },
      "nopass" => { column: "is_added", values: [ 0 ] },
      "ban"    => { column: "punishment_status", values: [ 3 ] },
      "mute"   => { column: "punishment_status", values: [ 2 ] }
    }

    filter_groups = Hash.new { |h, k| h[k] = [] }
    filters.each do |f|
      map = filter_map[f]
      filter_groups[map[:column]] += map[:values] if map
    end

    filter_clauses = filter_groups.map do |column, values|
      "#{column} IN (#{values.uniq.join(',')})"
    end
    filter_where = filter_clauses.any? ? "(#{filter_clauses.join(" AND ")})" : nil


    search_where = if search.present?
      term = "'%#{search.gsub("'", "''")}%'"
      <<~SQL.squish
        (lower(minecraft_nickname) LIKE #{term} OR lower(discord_username) LIKE #{term})
      SQL
    end

    where_clauses = [filter_where, search_where].compact
    where_sql     = where_clauses.any? ? "WHERE #{where_clauses.join(" AND ")}" : ""

    @total_count = ClickHouse.connection.select_value("SELECT count() FROM users #{where_sql}").to_i
    @total_pages = (@total_count / per_page.to_f).ceil.clamp(1, 10_000)
    page = page > @total_pages ? 1 : page

    @page     = page
    @per_page = per_page
    offset    = (page - 1) * per_page

    sql = <<~SQL
      SELECT user_id, discord_username, minecraft_nickname, is_added, punishment_status
      FROM users
      #{where_sql}
      ORDER BY #{sort} #{order}
      LIMIT #{per_page} OFFSET #{offset}
    SQL

    @players = ClickHouse.connection.select_all(sql)
  end

  private

  def is_admin?
    unless current_user && (current_user.role_name == "DEV" || current_user.role_name == "OWNER")
      redirect_to localized_root_path
    end
  end

  def update_users_data
    @result = ClickHouse.connection.select_all("SELECT count() AS cnt FROM users")
    count  = @result.first["cnt"].to_i
    Rails.logger.info "[Admin] Начальное количество записей в ClickHouse: #{count}"
    ready = 0

    if count.zero?
      produce_with_retries("update_users_data", payload: {})

      10.times do
        sleep 0.5
        @result = ClickHouse.connection.select_all("SELECT count() AS cnt FROM users")
        ready = @result.first["cnt"].to_i
        Rails.logger.info "[Admin] Попытка синхронизации ClickHouse — найдено записей: #{ready}"
        break if ready > 0
      end
    else
      ready = count
    end

    if ready == 0
      Rails.logger.error "[Admin] Не удалось получить данные из ClickHouse после синхронизации"
      session[:alert] = "Ошибка получения информации о пользователях"
      redirect_to localized_root_path
    else
      Rails.logger.info "[Admin] Данные ClickHouse готовы, всего записей: #{ready}"
    end
  end
end
