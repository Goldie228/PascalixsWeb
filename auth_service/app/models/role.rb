class Role < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :color, presence: true
end
