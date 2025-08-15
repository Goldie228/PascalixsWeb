# frozen_string_literal: true

require "net/http"
require "digest"

class AvatarUrlResolver
  CACHE_TTL_OK    = 6.hours
  CACHE_TTL_BAD   = 15.minutes
  CACHE_PREFIX    = "avatar:valid:"
  CONTENT_PREFIX  = "image/"

  def self.resolve(url:, fallback_url:)
    return fallback_url if url.blank?

    key = "#{CACHE_PREFIX}#{Digest::SHA256.hexdigest(url)}"
    cached = REDIS_CLIENT.get(key)
    case cached
    when "ok"  then return url
    when "bad" then return fallback_url
    end

    if url_alive?(url)
      REDIS_CLIENT.setex(key, CACHE_TTL_OK.to_i, "ok")
      url
    else
      REDIS_CLIENT.setex(key, CACHE_TTL_BAD.to_i, "bad")
      fallback_url
    end
  rescue => e
    Rails.logger.warn("[AvatarUrlResolver] fail: #{e.class} #{e.message}")
    fallback_url
  end

  def self.url_alive?(url)
    uri = URI.parse(url)

    Net::HTTP.start(
      uri.host, uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: 1, read_timeout: 1
    ) do |http|
      # Пытаемся HEAD, иначе пробуем GET первого байта
      resp = http.request(Net::HTTP::Head.new(uri.request_uri))
      unless successish?(resp)
        get = Net::HTTP::Get.new(uri.request_uri)
        get["Range"] = "bytes=0-0"
        resp = http.request(get)
      end

      successish?(resp) && image_content?(resp)
    end
  rescue
    false
  end

  def self.successish?(resp)
    resp.is_a?(Net::HTTPSuccess) || resp.is_a?(Net::HTTPRedirection)
  end

  def self.image_content?(resp)
    ct = resp["content-type"]
    ct && ct.downcase.start_with?(CONTENT_PREFIX)
  end
end
