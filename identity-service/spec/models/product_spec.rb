require "rails_helper"

RSpec.describe Product, type: :model do
  # --- Validations ---
  describe "validations" do
    subject { build(:product) }

    it { is_expected.to validate_presence_of(:product_type) }
    it { is_expected.to validate_uniqueness_of(:product_type) }

    it { is_expected.to validate_presence_of(:price) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
  end

  # --- Factory ---
  describe "factory" do
    it "builds a valid product" do
      expect(build(:product)).to be_valid
    end

    it "creates a product" do
      expect { create(:product) }.to change(described_class, :count).by(1)
    end
  end

  # --- Traits ---
  describe "traits" do
    it "builds a free product with zero price" do
      product = build(:product, :free)
      expect(product.price).to eq(0)
    end

    it "builds a premium product with higher price" do
      product = build(:product, :premium)
      expect(product.price).to be >= 100
    end
  end

  # --- Uniqueness ---
  describe "uniqueness" do
    it "does not allow duplicate product_type" do
      create(:product, product_type: "vip_pass")
      duplicate = build(:product, product_type: "vip_pass")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:product_type]).to be_present
    end
  end

  # --- Price boundary ---
  describe "price boundaries" do
    it "allows zero price" do
      product = build(:product, price: 0)
      expect(product).to be_valid
    end

    it "rejects negative price" do
      product = build(:product, price: -1)
      expect(product).not_to be_valid
    end
  end
end
