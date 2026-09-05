class UserRegistrationConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      Rails.logger.debug "Received registration event: #{message.payload}"
    end
  end
end
