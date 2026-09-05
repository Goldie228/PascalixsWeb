require "rails_helper"

RSpec.describe Role, type: :model do
  # ── Валидации ─────────────────────────────────────────────────────────
  describe "validations" do
    subject { build(:role) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:color) }
  end

  # ── Фабрика ───────────────────────────────────────────────────────────
  describe "factory" do
    it "has a valid factory" do
      expect(build(:role)).to be_valid
    end

    it "creates a valid record" do
      expect(create(:role)).to be_persisted
    end
  end

  # ── Граничные случаи ──────────────────────────────────────────────────
  describe "edge cases" do
    it "is invalid without a name" do
      role = build(:role, name: nil)
      expect(role).not_to be_valid
      expect(role.errors[:name]).to be_present
    end

    it "is invalid with a duplicate name" do
      create(:role, name: "UniqueRole")
      duplicate = build(:role, name: "UniqueRole")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "is invalid without a color" do
      role = build(:role, color: nil)
      expect(role).not_to be_valid
      expect(role.errors[:color]).to be_present
    end

    it "allows different names" do
      create(:role, name: "RoleA")
      role_b = build(:role, name: "RoleB")
      expect(role_b).to be_valid
    end
  end

  # ── Связи ─────────────────────────────────────────────────────────────
  # Модель Role не определяет явных связей.
  # Users принадлежат :role, но Role не имеет has_many :users.
end
