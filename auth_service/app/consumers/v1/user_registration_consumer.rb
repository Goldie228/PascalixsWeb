
module V1
  class UserRegistrationConsumer < Karafka::BaseConsumer
    def consume
      messages.each do |message|
        data = JSON.parse(message.payload)
        puts "Received registration event: #{data}"
      end
    end
  end
end
