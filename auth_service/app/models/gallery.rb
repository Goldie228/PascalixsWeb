class Gallery < ApplicationRecord
  has_many :photos, dependent: :destroy
  accepts_nested_attributes_for :photos

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 4096 }

  validate :cannot_be_published_without_photos

  private

  def cannot_be_published_without_photos
    if published? && photos.empty?
      errors.add(:published, "cannot be published without photos")
    end
  end
end
