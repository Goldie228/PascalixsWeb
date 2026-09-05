class Notification < ApplicationRecord
  # Push notification record stored after FCM delivery
  #
  # Columns:
  #   user_id :integer
  #   type    :string
  #   title   :string
  #   message :text
  #   read    :boolean, default: false
  #   created_at :datetime
  #   updated_at :datetime

  validates :user_id, presence: true
  validates :type, presence: true
  validates :message, presence: true

  scope :unread, -> { where(read: false) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
end
