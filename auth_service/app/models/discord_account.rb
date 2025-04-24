class DiscordAccount < ApplicationRecord
  belongs_to :user, inverse_of: :discord_account
  before_validation :generate_uuid, on: :create

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  validates :discord_id,
    presence: { message: I18n.t("activerecord.errors.messages.blank") },
    uniqueness: { message: I18n.t("activerecord.errors.messages.taken") }

  validates :username,
    presence: { message: I18n.t("activerecord.errors.messages.blank") }

  validates :discriminator,
    presence: { message: I18n.t("activerecord.errors.messages.blank") },
    unless: -> { discriminator.blank? }

  validates :email,
    presence: { message: I18n.t("activerecord.errors.messages.blank") },
    format: {
      with: VALID_EMAIL_REGEX,
      message: I18n.t("activerecord.errors.messages.invalid")
    }

  validates :avatar,
    presence: { message: I18n.t("activerecord.errors.messages.blank") }

  validates :user_id,
    uniqueness: { message: I18n.t("activerecord.errors.messages.taken") }
end
