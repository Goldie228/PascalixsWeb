class CodeValidationChannel < ApplicationCable::Channel
  def subscribed
    # Обратите внимание, что ключ формируется именно из params[:user_id]
    stream_from "code_validation_status_#{params[:user_id]}"
  end
end
