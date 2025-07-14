class DropedUser < ApplicationRecord
  validates :name,
    presence: { message: :blank },
    uniqueness: { message: I18n.t("activerecord.errors.messages.taken") },
    length: {
      minimum: 3,
      maximum: 27,
      too_short: I18n.t("activerecord.errors.models.minecraft_account.attributes.nickname.too_short"),
      too_long: I18n.t("activerecord.errors.models.minecraft_account.attributes.nickname.too_long")
    },
    format: {
      with: /\A[a-zA-Z0-9_]+\z/,
      message: :format
    }
end
