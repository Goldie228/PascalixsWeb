require "rails_helper"

RSpec.describe Purchase, type: :model do
  # --- Связи ---
  describe "associations" do
    it { is_expected.to belong_to(:purchaser).class_name("User") }
    it { is_expected.to belong_to(:target).class_name("User").optional }
    it { is_expected.to belong_to(:punishment).class_name("UsersPunishment").optional }
  end

  # --- Валидации ---
  describe "validations" do
    subject { build(:purchase) }

    it { is_expected.to validate_presence_of(:purchase_type) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_length_of(:currency).is_at_most(8) }
    it { is_expected.to validate_presence_of(:purchaser) }

    it { is_expected.to validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
  end

  # --- Enum: purchase_type ---
  describe "enum :purchase_type" do
    it "defines expected purchase types" do
      expect(described_class.purchase_types.keys).to match_array(
        %w[pass_purchase pass_gift sponsor unban unmute]
      )
    end

    it "provides query methods with prefix" do
      purchase = build(:purchase, :pass_purchase)
      expect(purchase).to respond_to(:type_pass_purchase?)
      expect(purchase).to respond_to(:type_pass_gift?)
      expect(purchase).to respond_to(:type_sponsor?)
      expect(purchase).to respond_to(:type_unban?)
      expect(purchase).to respond_to(:type_unmute?)
    end
  end

  # --- Enum: status ---
  describe "enum :status" do
    it "defines expected statuses" do
      expect(described_class.statuses.keys).to match_array(%w[pending approved rejected])
    end

    it "provides query methods with prefix" do
      purchase = build(:purchase)
      expect(purchase).to respond_to(:status_pending?)
      expect(purchase).to respond_to(:status_approved?)
      expect(purchase).to respond_to(:status_rejected?)
    end
  end

  # --- Кастомные валидации ---
  describe "custom validations" do
    describe "target_required_for_gift_and_actions" do
      it "requires target_user_id for pass_gift" do
        purchase = build(:purchase, :pass_gift)
        purchase.target_user_id = nil
        expect(purchase).not_to be_valid
        expect(purchase.errors[:target_user_id]).to be_present
      end

      it "is valid for pass_gift with target" do
        purchase = build(:purchase, :pass_gift)
        expect(purchase).to be_valid
      end
    end

    describe "punishment_presence_for_unban_unmute_if_provided" do
      it "is invalid when punishment is inactive for unban" do
        punishment = create(:users_punishment, :expired)
        purchase = build(:purchase, :unban, punishment: punishment)
        expect(purchase).not_to be_valid
        expect(purchase.errors[:punishment_id]).to be_present
      end

      it "is valid when punishment is active for unban" do
        punishment = create(:users_punishment, :ban)
        purchase = build(:purchase, :unban, punishment: punishment)
        expect(purchase).to be_valid
      end

      it "is invalid when punishment is inactive for unmute" do
        punishment = create(:users_punishment, :expired)
        purchase = build(:purchase, :unmute, punishment: punishment)
        expect(purchase).not_to be_valid
      end
    end

    describe "receipt_image_only" do
      it "rejects non-image receipts" do
        purchase = create(:purchase)
        purchase.receipt.attach(
          io: StringIO.new("fake pdf"),
          filename: "receipt.pdf",
          content_type: "application/pdf"
        )
        expect(purchase).not_to be_valid
        expect(purchase.errors[:receipt]).to include("должно быть изображением (PNG/JPG)")
      end

      it "rejects receipts larger than 5 MB" do
        purchase = create(:purchase)
        purchase.receipt.attach(
          io: StringIO.new("x" * 6.megabytes),
          filename: "receipt.jpg",
          content_type: "image/jpeg"
        )
        expect(purchase).not_to be_valid
        expect(purchase.errors[:receipt]).to include("слишком большой файл (макс 5 МБ)")
      end

      it "accepts valid image receipts" do
        purchase = create(:purchase, :with_receipt)
        # Важны только ошибки валидации receipt
        receipt_errors = purchase.errors[:receipt]
        expect(receipt_errors).to be_empty
      end
    end
  end

  # --- Колбэк before_validation ---
  describe "before_validation :assign_default_target_for_selfish_types" do
    it "sets target to purchaser for pass_purchase when target is blank" do
      purchase = build(:purchase, :pass_purchase, target_user_id: nil)
      purchase.valid?
      expect(purchase.target_user_id).to eq(purchase.purchaser_user_id)
    end

    it "sets target to purchaser for sponsor when target is blank" do
      purchase = build(:purchase, :sponsor, target_user_id: nil)
      purchase.valid?
      expect(purchase.target_user_id).to eq(purchase.purchaser_user_id)
    end

    it "does not override existing target for pass_purchase" do
      other_user = create(:user)
      purchase = build(:purchase, :pass_purchase, target_user_id: other_user.id)
      purchase.valid?
      expect(purchase.target_user_id).to eq(other_user.id)
    end
  end

  # --- Скоупы ---
  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        old_purchase = create(:purchase, created_at: 2.days.ago)
        new_purchase = create(:purchase, created_at: 1.hour.ago)

        result = described_class.recent
        expect(result.first).to eq(new_purchase)
        expect(result.last).to eq(old_purchase)
      end
    end
  end

  # --- Фабрика ---
  describe "factory" do
    it "builds a valid purchase" do
      expect(build(:purchase)).to be_valid
    end

    it "creates a purchase" do
      expect { create(:purchase) }.to change(described_class, :count).by(1)
    end
  end

  # --- Трейты ---
  describe "traits" do
    it "builds a pass_purchase" do
      purchase = build(:purchase, :pass_purchase)
      expect(purchase.purchase_type).to eq("pass_purchase")
    end

    it "builds a pass_gift with target" do
      purchase = build(:purchase, :pass_gift)
      expect(purchase.purchase_type).to eq("pass_gift")
      expect(purchase.target_user_id).to be_present
    end

    it "builds a sponsor" do
      purchase = build(:purchase, :sponsor)
      expect(purchase.purchase_type).to eq("sponsor")
    end

    it "builds an unban with punishment" do
      purchase = build(:purchase, :unban)
      expect(purchase.purchase_type).to eq("unban")
      expect(purchase.punishment).to be_present
    end

    it "builds an unmute with punishment" do
      purchase = build(:purchase, :unmute)
      expect(purchase.purchase_type).to eq("unmute")
      expect(purchase.punishment).to be_present
    end

    it "builds an approved purchase" do
      purchase = build(:purchase, :approved)
      expect(purchase.status).to eq("approved")
    end

    it "builds a rejected purchase" do
      purchase = build(:purchase, :rejected)
      expect(purchase.status).to eq("rejected")
    end

    it "builds a purchase with receipt" do
      purchase = create(:purchase, :with_receipt)
      expect(purchase.receipt).to be_attached
    end
  end
end
