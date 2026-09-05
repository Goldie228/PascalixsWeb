class FlashChannel < ApplicationCable::Channel
  def subscribed
    stream_from "flash_channel"
  end
end
