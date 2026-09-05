class FCMService
  # Send a push notification via Firebase Cloud Messaging
  #
  # @param token [String] FCM device token
  # @param title [String] notification title
  # @param body [String] notification body
  # @param data [Hash] optional data payload
  def self.send(token:, title:, body:, data: {})
    server_key = ENV.fetch('FCM_SERVER_KEY', nil)
    return nil unless server_key

    project_id = ENV.fetch('FCM_PROJECT_ID', 'pascalixs')

    response = HTTParty.post(
      "https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send",
      headers: {
        'Authorization' => "Bearer #{server_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        message: {
          token: token,
          notification: {
            title: title,
            body: body
          },
          data: data.transform_values(&:to_s)
        }
      }.to_json
    )

    unless response.success?
      Rails.logger.error "FCM send failed (status #{response.code}): #{response.body}"
      raise "FCM send failed: #{response.body}"
    end

    JSON.parse(response.body)
  end
end
