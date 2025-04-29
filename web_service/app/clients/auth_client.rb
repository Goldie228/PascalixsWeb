class AuthClient
  include HTTParty
  base_uri ENV['AUTH_SERVICE_URL']

  def self.get_user(user_id, fields)
    if user_id == :current
      get("/api/v1/me/fields", query: { fields: fields.join(',') })
    else
      get("/api/v1/users/#{user_id}/fields", query: { fields: fields.join(',') })
    end
  rescue StandardError => e
    Rails.logger.error "AuthClient Error: #{e.message}"
    nil
  end
end
