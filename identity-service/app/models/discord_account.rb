class DiscordAccount < ApplicationRecord
  belongs_to :user, inverse_of: :discord_account
  has_many :discord_avatars, dependent: :destroy
  has_one_attached :avatar_file

  before_validation :generate_uuid, on: :create
  after_commit :publish_user_event, on: [ :update ]

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  VALID_AVATAR_STATUSES = %w[pending approved rejected]

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

  # Метод для добавления новой аватарки
  def add_avatar(avatar_url)
    # Создаем запись о новой аватарке
    new_avatar = discord_avatars.create(
      original_url: avatar_url,
      status: 'approved'
    )

    # Запускаем фоновую задачу для загрузки и обработки аватарки
    DownloadDiscordAvatarJob.perform_later(new_avatar.id, avatar_url)
  end

  def publish_user_event
    UserDataProducer.publish(self.user)
  end
end
