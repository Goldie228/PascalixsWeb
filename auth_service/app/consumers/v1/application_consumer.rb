
module V1
  class ApplicationConsumer < Karafka::BaseConsumer
    def consume
      messages.each do |message|
        puts "Received message: #{message.payload}"
      end
    end
  end
end