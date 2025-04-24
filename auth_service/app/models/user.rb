class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :validatable,
  :two_factor_authenticatable, :two_factor_backupable, otp_backup_code_length: 6

  has_one :discord_account, dependent: :destroy, inverse_of: :user
  has_one :minecraft_account, dependent: :destroy, inverse_of: :user

  validates :about_me, length: {
    maximum: 5000,
    too_long: I18n.t("activerecord.errors.messages.too_long", count: 5000)
  }, allow_blank: true

  validate :must_have_discord_account

  encrypts :otp_secret

  before_save :downcase_email

  # Отключаем валидацию email для новых записей, создаваемых через Discord
  def self.skip_email_validation
    @skip_email_validation = true
    yield
  ensure
    @skip_email_validation = false
  end

  def self.skip_email_validation?
    !!@skip_email_validation
  end

  # Переопределяем валидацию email от Devise
  def email_required?
    return false if self.class.skip_email_validation?
    super
  end

  def email
    discord_account&.email || ""
  end

  def email=(value)
    if discord_account
      discord_account.email = value
      discord_account.save if discord_account.changed?
    else
      build_discord_account(email: value)
    end
  end

  def will_save_change_to_email?
    false
  end

  def email_changed?
    false
  end

  def valid_password?(password)
    return false unless minecraft_account
    BCrypt::Password.new(minecraft_account.password_hash) == password
  end

  def password=(new_password)
    if minecraft_account
      minecraft_account.password_hash = BCrypt::Password.create(new_password)
      minecraft_account.save
    else
      build_minecraft_account(password_hash: BCrypt::Password.create(new_password))
    end
  end

  def password_required?
    minecraft_account.present? && minecraft_account.password_hash.blank?
  end

  def require_two_factor_authentication?
    # Проверяем время последней 2FA
    last_auth_time = Thread.current[:request].session[:last_auth_time] if Thread.current[:request]
    return false if last_auth_time && last_auth_time > Time.current.to_i - 1.minute.to_i
    true
  end

  def update_last_auth_time
    update(consumed_timestep: Time.current.to_i)
  end

  def generate_otp_qr_code
    uri = otp_provisioning_uri(email, issuer: "Pascalixs")
    qrcode = RQRCode::QRCode.new(uri)
    qrcode.as_svg(module_size: 4)
  end

  def validate_and_consume_otp!(code)
    totp = ROTP::TOTP.new(otp_secret, drift_behind: 120, drift_ahead: 120)
    if totp.verify(code, drift_behind: 120, drift_ahead: 120)
      # Логируем успех для отладки
      Rails.logger.info("OTP verified successfully for user: #{id}, code: #{code}")
      true  # Или выполните дополнительную логику, если нужно
    else
      Rails.logger.error("OTP verification failed for user: #{id}, attempted code: #{code}, expected: #{totp.now}")
      false
    end
  end

  after_commit :publish_user_event, on: [:create, :update]

  private

  def must_have_discord_account
    return if Rails.env.test?
    errors.add(:base, I18n.t("activerecord.errors.messages.must_have_discord_account")) unless discord_account.present?
  end

  def publish_user_event
    topic = 'user_events'
    payload = { id: id, action: previous_changes.key?('created_at') ? 'created' : 'updated' }.to_json
    Karafka.produce(topic, payload)  # Используйте Karafka для публикации
  end

  def downcase_email
    self.email = email.downcase if email.present?
  end
end
