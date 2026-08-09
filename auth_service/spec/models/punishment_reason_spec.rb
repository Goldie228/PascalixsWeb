require "rails_helper"

RSpec.describe PunishmentReason, type: :model do
  # --- Associations ---
  describe "associations" do
    it { is_expected.to have_many(:users_punishments).dependent(:destroy) }
  end

  # --- Validations ---
  describe "validations" do
    subject { build(:punishment_reason) }

    it { is_expected.to validate_presence_of(:punishment_type) }
    it { is_expected.to validate_inclusion_of(:punishment_type).in_array(%w[ban mute]) }

    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:rule_number) }
    it { is_expected.to validate_presence_of(:price) }

    it { is_expected.to validate_numericality_of(:rule_number).only_integer.is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0) }

    it "validates uniqueness of rule_number scoped to punishment_type" do
      create(:punishment_reason, punishment_type: "ban", rule_number: 1)
      duplicate = build(:punishment_reason, punishment_type: "ban", rule_number: 1)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:rule_number]).to be_present
    end

    it "allows same rule_number for different punishment_types" do
      create(:punishment_reason, punishment_type: "ban", rule_number: 42)
      other_type = build(:punishment_reason, punishment_type: "mute", rule_number: 42)
      expect(other_type).to be_valid
    end
  end

  # --- Factory ---
  describe "factory" do
    it "builds a valid punishment reason" do
      expect(build(:punishment_reason)).to be_valid
    end

    it "creates a punishment reason" do
      expect { create(:punishment_reason) }.to change(described_class, :count).by(1)
    end
  end

  # --- Traits ---
  describe "traits" do
    it "builds a ban type" do
      reason = build(:punishment_reason, :ban)
      expect(reason.punishment_type).to eq("ban")
    end

    it "builds a mute type" do
      reason = build(:punishment_reason, :mute)
      expect(reason.punishment_type).to eq("mute")
    end

    it "builds a free reason with zero price" do
      reason = build(:punishment_reason, :free)
      expect(reason.price).to eq(0)
    end
  end

  # --- VALID_TYPES constant ---
  describe "VALID_TYPES" do
    it "contains ban and mute" do
      expect(described_class::VALID_TYPES).to match_array(%w[ban mute])
    end

    it "is frozen" do
      expect(described_class::VALID_TYPES).to be_frozen
    end
  end
end
