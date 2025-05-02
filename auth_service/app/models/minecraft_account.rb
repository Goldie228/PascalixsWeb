class MinecraftAccount < ApplicationRecord
  require "digest"

  before_validation :generate_uuid, on: :create
  belongs_to :user, inverse_of: :minecraft_account
  before_save :hash_password, if: :password_changed?

  attr_accessor :password, :password_confirmation

  validates :nickname,
    presence: { message: I18n.t("activerecord.errors.messages.blank") },
    uniqueness: { message: I18n.t("activerecord.errors.messages.taken") },
    length: {
      minimum: 3,
      maximum: 27,
      too_short: I18n.t("activerecord.errors.models.minecraft_account.attributes.nickname.too_short"),
      too_long: I18n.t("activerecord.errors.models.minecraft_account.attributes.nickname.too_long")
    },
    format: {
      with: /\A[a-zA-Z0-9_-]+\z/,
      message: I18n.t("activerecord.attributes.minecraft_account.format")
    }

  validates :password,
    presence: true,
    confirmation: { case_sensitive: true }
  
  validates :password_confirmation,
    presence: true

  validate :password_complexity
  validate :username_not_in_droped_users
  validates :user_id, uniqueness: { message: I18n.t("activerecord.errors.messages.taken") }

  # Аутентификация по паролю
  def authenticate(plain_password)
    parts = password_hash.split("$")
    return false unless parts.length == 4

    salt = parts[2]
    expected_hash = parts[3]
    first_hash = Digest::SHA256.hexdigest(plain_password)
    computed_hash = Digest::SHA256.hexdigest(first_hash + salt)
    computed_hash == expected_hash
  end

  private

  def password_changed?
    password.present?
  end

  def hash_password
    return if password.blank?

    salt = SecureRandom.hex(8)
    first_hash = Digest::SHA256.hexdigest(password)
    final_hash = Digest::SHA256.hexdigest(first_hash + salt)
    self.password_hash = "$SHA$#{salt}$#{final_hash}"
  end

  # Проверка сложности пароля
  def password_complexity
    if password.present?
      unless password.match?(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/)
        errors.add(:password, I18n.t("activerecord.errors.messages.complexity"))
      end
    end
  end

  # Проверка, что username не в таблице droped_users
  def username_not_in_droped_users
    if DropedUser.exists?(name: self.nickname)
      errors.add(:nickname, I18n.t("activerecord.errors.messages.username_in_droped_users"))
    end
  end

  def generate_uuid
    self.id = SecureRandom.uuid if self.id.nil?
  end
end
