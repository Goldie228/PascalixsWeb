class AuthServiceClient
  BASE_URL = ENV.fetch("AUTH_SERVICE_URL") { "http://localhost:3002" }
  API_KEY = ENV.fetch("INTER_SERVICE_API_KEY") { "" }

  # --- Authentication ---

  def self.authenticate(nickname, password)
    post("/api/v1/sessions", { nickname:, password: }.to_json)
  end

  def self.logout(user_id)
    delete("/api/v1/sessions", headers: { "X-User-ID" => user_id })
  end

  # --- User Data ---

  def self.get_user(user_id)
    get("/api/v1/users/#{user_id}")
  end

  def self.get_player_profile(nickname)
    get("/api/v1/players/#{nickname}")
  end

  def self.get_punishment_history(nickname)
    get("/api/v1/players/#{nickname}/punishments")
  end

  def self.lookup_email(email)
    get("/api/v1/lookup_email", headers: { "X-Email" => email })
  end

  # --- Password Operations ---

  def self.check_password(nickname, password)
    get("/api/v1/players/#{nickname}/password_check", headers: { "X-Password" => password })
  end

  def self.validate_password(nickname, password, locale: nil)
    path = if locale
             "/#{locale}/api/v1/players/#{nickname}/validate_password"
           else
             "/api/v1/players/#{nickname}/validate_password"
           end
    post(path, { password: }.to_json)
  end

  # --- 2FA ---

  def self.two_factor_verify(user_id, otp)
    post("/api/v1/two_factor_authentication/verify", { user_id:, otp: }.to_json)
  end

  # --- Account Management ---

  def self.update_email(user_id, new_email)
    put("/api/v1/users/#{user_id}/email", { email: new_email }.to_json)
  end

  # --- OAuth ---

  def self.discord_auth_url
    get("/api/v1/auth/discord")
  end

  # --- Punishment Appeal ---

  def self.get_punishment_appeal(punishment_id)
    get("/api/v1/user/punishment_appeal/#{punishment_id}")
  end

  # --- Reports ---

  def self.revoke_report(report_id)
    post("/api/v1/reports/revoke/#{report_id}", {}.to_json)
  end

  private

  def self.headers
    {
      "Authorization" => "Bearer #{API_KEY}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  def self.get(path, headers: {})
    final_headers = headers.merge(self.headers)
    response = HTTParty.get("#{BASE_URL}#{path}", headers: final_headers, timeout: 5)
    response.success? ? response.parsed_response : nil
  rescue => e
    Rails.logger.error "AuthServiceClient GET error: #{e.message}"
    nil
  end

  def self.post(path, body)
    response = HTTParty.post("#{BASE_URL}#{path}", headers: self.headers, body:, timeout: 5)
    response.success? ? response.parsed_response : nil
  rescue => e
    Rails.logger.error "AuthServiceClient POST error: #{e.message}"
    nil
  end

  def self.delete(path, headers:)
    final_headers = headers.merge(self.headers)
    response = HTTParty.delete("#{BASE_URL}#{path}", headers: final_headers, timeout: 5)
    response.success? ? response.parsed_response : nil
  rescue => e
    Rails.logger.error "AuthServiceClient DELETE error: #{e.message}"
    nil
  end

  def self.put(path, body)
    response = HTTParty.put("#{BASE_URL}#{path}", headers: self.headers, body:, timeout: 5)
    response.success? ? response.parsed_response : nil
  rescue => e
    Rails.logger.error "AuthServiceClient PUT error: #{e.message}"
    nil
  end
end
