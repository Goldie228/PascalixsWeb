# frozen_string_literal: true

require "net/http"

class AvatarUrlResolver
  CONTENT_PREFIX = "image/"

  def self.resolve(url:, fallback_url:)
    return fallback_url if url.blank?
    
    url_alive?(url) ? url : fallback_url
  rescue => e
    Rails.logger.warn("[AvatarUrlResolver] fail: #{e.class} #{e.message}")
    fallback_url
  end

  def self.url_alive?(url)
    uri = URI.parse(url)
    return false unless ["http", "https"].include?(uri.scheme)

    # Создаем HTTP объект с минимальными таймаутами
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 0.3
    http.read_timeout = 0.3
    
    # Отключаем проверку SSL для локальных серверов
    if uri.host.include?("localhost") || uri.host.include?("127.0.0.1")
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    # Пробуем только GET запрос с Range (самый быстрый вариант)
    get = Net::HTTP::Get.new(uri.request_uri)
    get["Range"] = "bytes=0-0" # Запрашиваем только первый байт
    
    response = quick_follow_redirects(http, get)
    successish?(response) && image_content?(response)
  rescue
    false
  end

  # Упрощенный метод для следования за редиректами с минимальной задержкой
  def self.quick_follow_redirects(http, request, limit = 2)
    return nil if limit <= 0

    response = http.request(request)
    
    if response.is_a?(Net::HTTPRedirection) && location = response['location']
      redirect_uri = URI.parse(location)
      
      # Быстро создаем новое соединение для редиректа
      new_http = Net::HTTP.new(redirect_uri.host, redirect_uri.port)
      new_http.use_ssl = (redirect_uri.scheme == "https")
      new_http.open_timeout = 0.3
      new_http.read_timeout = 0.3
      
      if redirect_uri.host.include?("localhost") || redirect_uri.host.include?("127.0.0.1")
        new_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      
      # Создаем новый запрос для редиректа
      new_request = request.class.new(redirect_uri.request_uri)
      new_request["Range"] = "bytes=0-0" if new_request.is_a?(Net::HTTP::Get)
      
      quick_follow_redirects(new_http, new_request, limit - 1)
    else
      response
    end
  end

  def self.successish?(resp)
    resp&.is_a?(Net::HTTPSuccess) || resp&.code == "206" # Partial Content
  end

  def self.image_content?(resp)
    return false unless resp
    ct = resp["content-type"]
    ct && ct.downcase.start_with?(CONTENT_PREFIX)
  end
end
