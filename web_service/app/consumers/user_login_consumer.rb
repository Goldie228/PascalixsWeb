
class UserLoginConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = JSON.parse(message.payload)

      session[:user_data] = payload['user']
      
    end
  end
end
