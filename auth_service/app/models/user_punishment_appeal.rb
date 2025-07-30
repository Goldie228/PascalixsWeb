class UserPunishmentAppeal < ApplicationRecord
  belongs_to :punishment, class_name: "UsersPunishment", foreign_key: :punishment_id

  enum status: {
    pending:  "pending",
    rejected: "rejected",
    accepted: "accepted"
  }

  validates :user_message, length: { maximum: 500 }, allow_blank: true
  validates :admin_comment, length: { maximum: 500 }, allow_blank: true
  validates :status, inclusion: { in: statuses.keys }

  validates :punishment_id, uniqueness: true

  scope :reappealable, -> { where(can_reappeal: true) }

  def summary
    "#{status.capitalize}: #{user_message.to_s.truncate(80)}"
  end
end
