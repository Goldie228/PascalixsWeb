
class Photo < ApplicationRecord
  belongs_to :gallery
  has_one_attached :file

  validates :file, presence: true
  validates :title, length: { maximum: 255 }
end
