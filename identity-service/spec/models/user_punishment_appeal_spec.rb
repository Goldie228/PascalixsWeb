require "rails_helper"

RSpec.describe UserPunishmentAppeal, type: :model do
  # --- Associations ---
  describe "associations" do
    it { is_expected.to belong_to(:punishment).class_name("UsersPunishment") }
  end

  # --- Validations ---
  describe "validations" do
    subject { build(:user_punishment_appeal) }

    it { is_expected.to validate_length_of(:user_message).is_at_most(500) }
    it { is_expected.to validate_length_of(:admin_comment).is_at_most(500) }

    it "validates uniqueness of punishment_id" do
      existing = create(:user_punishment_appeal)
      duplicate = build(:user_punishment_appeal, punishment: existing.punishment)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:punishment_id]).to be_present
    end
  end

  # --- Enum: status ---
  describe "enum :status" do
    it "defines pending, rejected, and accepted statuses" do
      expect(described_class.statuses.keys).to match_array(%w[pending rejected accepted])
    end

    it "defaults to pending" do
      appeal = build(:user_punishment_appeal)
      expect(appeal.status).to eq("pending")
    end

    it "can transition to accepted" do
      appeal = create(:user_punishment_appeal, :pending)
      appeal.accepted!
      expect(appeal).to be_accepted
    end

    it "can transition to rejected" do
      appeal = create(:user_punishment_appeal, :pending)
      appeal.rejected!
      expect(appeal).to be_rejected
    end
  end

  # --- Scopes ---
  describe "scopes" do
    describe ".reappealable" do
      let!(:reappealable) { create(:user_punishment_appeal, can_reappeal: true) }
      let!(:non_reappealable) { create(:user_punishment_appeal, can_reappeal: false) }

      it "returns only appeals where can_reappeal is true" do
        expect(described_class.reappealable).to include(reappealable)
        expect(described_class.reappealable).not_to include(non_reappealable)
      end
    end
  end

  # --- Instance methods ---
  describe "#summary" do
    it "returns status and truncated user_message" do
      appeal = build(:user_punishment_appeal, status: "pending", user_message: "Please help me")
      expect(appeal.summary).to eq("Pending: Please help me")
    end

    it "truncates long messages to 80 characters" do
      long_message = "A" * 100
      appeal = build(:user_punishment_appeal, status: "rejected", user_message: long_message)
      expect(appeal.summary.length).to be <= 100 # "Rejected: " + 80 chars + "..."
      expect(appeal.summary).to start_with("Rejected: ")
    end

    it "handles nil user_message" do
      appeal = build(:user_punishment_appeal, status: "accepted", user_message: nil)
      expect(appeal.summary).to eq("Accepted: ")
    end
  end

  # --- Factory ---
  describe "factory" do
    it "builds a valid appeal" do
      expect(build(:user_punishment_appeal)).to be_valid
    end

    it "creates an appeal" do
      expect { create(:user_punishment_appeal) }.to change(described_class, :count).by(1)
    end
  end

  # --- Traits ---
  describe "traits" do
    it "builds a pending appeal" do
      appeal = build(:user_punishment_appeal, :pending)
      expect(appeal.status).to eq("pending")
    end

    it "builds an accepted appeal" do
      appeal = build(:user_punishment_appeal, :accepted)
      expect(appeal.status).to eq("accepted")
      expect(appeal.admin_comment).to be_present
    end

    it "builds a rejected appeal" do
      appeal = build(:user_punishment_appeal, :rejected)
      expect(appeal.status).to eq("rejected")
      expect(appeal.can_reappeal).to be false
    end
  end
end
