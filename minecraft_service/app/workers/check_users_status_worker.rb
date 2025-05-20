require "net/http"
require "json"


class CheckUsersStatusWorker
  include Sidekiq::Worker

  URL = URI("https://api.mcsrvstat.us/2/#{ENV["MC_SERVER_IP"]}")

  def perform
    Rails.logger.info "[CheckUsersStatusWorker] Started checking online players"

    begin
      response = Net::HTTP.get(URL)
      Rails.logger.debug "[CheckUsersStatusWorker] Fetched response from API"

      begin
        data = JSON.parse(response)
      rescue JSON::ParserError => e
        Rails.logger.error "[CheckUsersStatusWorker] JSON parsing error: #{e.message}"
        return
      end

      unless data.dig("debug", "ping")
        Rails.logger.warn "[CheckUsersStatusWorker] Server did not respond to ping"
        return
      end

      players = data["players"]["list"] || []
      Rails.logger.info "[CheckUsersStatusWorker] Found #{players.size} players online"

      if players.empty?
        Rails.logger.info "[CheckUsersStatusWorker] No online players detected, exiting"
        return
      end

      send_players_online(players)

      Rails.logger.info "[CheckUsersStatusWorker] Successfully updated Redis with #{players.size} players"
    rescue => e
      Rails.logger.error "Error: #{e.message}"
    end
  end

  def send_players_online(players)
    REDIS_CLIENT.pipelined do |redis|
      players.each do |player|
        redis.setex("player_online:#{player}", 120, "true")
      end
    end
  end
end
