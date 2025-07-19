if defined?(errors) && errors.any?
  json.status "error"
  json.errors do
    errors.each do |field, message|
      json.set! field, Array(message).first
    end
  end
else
  json.status "success"
  json.message t('change_password.password_changed')
end
