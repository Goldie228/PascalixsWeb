class Product < ApplicationRecord
  validates :product_type, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
