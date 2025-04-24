
module V1
  class UserLoginConsumer < Karafka::BaseConsumer
    def consume
      messages.each do |message|
        data = JSON.parse(message.payload)
        puts "Received login event: #{data}"
      end
    end
  end
end
