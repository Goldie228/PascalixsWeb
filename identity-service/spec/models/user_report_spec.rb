require "rails_helper"

RSpec.describe UserReport, type: :model do
  # --- Связи ---
  describe "associations" do
    it { is_expected.to belong_to(:reporter).class_name("User") }
    it { is_expected.to belong_to(:reported_user).class_name("User") }
    it { is_expected.to have_many(:report_attachments).dependent(:destroy) }
  end

  # --- Валидации ---
  describe "validations" do
    subject { build(:user_report) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(80) }

    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_length_of(:description).is_at_most(5000) }
  end

  # --- Кастомные валидации ---
  describe "custom validations" do
    describe "reporter_cannot_be_reported_user" do
      it "is invalid when reporter is the same as reported_user" do
        user = create(:user)
        report = build(:user_report)
        report.reporter = user
        report.reported_user = user
        expect(report).not_to be_valid
        expect(report.errors[:base]).to include("Вы не можете пожаловаться на самого себя")
      end

      it "is valid when reporter and reported_user are different" do
        report = build(:user_report)
        expect(report).to be_valid
      end
    end

    describe "validate_attachments_count" do
      it "is invalid with more than 12 attachments" do
        report = build(:user_report)
        # Эмулируем 13 вложений через заглушку размера
        attachments_double = Array.new(13) { double("attachment") }
        allow(report.attachments).to receive(:size).and_return(13)
        report.valid?
        expect(report.errors[:attachments]).to include("можно прикрепить не более 12 файлов")
      end
    end

    describe "validate_attachments_type" do
      it "rejects unsupported content types" do
        report = build(:user_report)
        bad_attachment = double(
          "attachment",
          content_type: "application/pdf",
          filename: "doc.pdf",
          byte_size: 1024
        )
        allow(report.attachments).to receive(:size).and_return(1)
        allow(report.attachments).to receive(:each).and_yield(bad_attachment)
        report.valid?
        expect(report.errors[:attachments]).to be_present
      end

      it "accepts supported content types" do
        report = build(:user_report)
        good_attachment = double(
          "attachment",
          content_type: "image/jpeg",
          filename: "photo.jpg",
          byte_size: 1024
        )
        allow(report.attachments).to receive(:size).and_return(1)
        allow(report.attachments).to receive(:each).and_yield(good_attachment)
        expect(report).to be_valid
      end
    end

    describe "validate_attachments_size" do
      it "rejects files larger than 2 GB" do
        report = build(:user_report)
        big_attachment = double(
          "attachment",
          content_type: "image/jpeg",
          filename: "huge.jpg",
          byte_size: 3.gigabytes
        )
        allow(report.attachments).to receive(:size).and_return(1)
        allow(report.attachments).to receive(:each).and_yield(big_attachment)
        report.valid?
        expect(report.errors[:attachments]).to be_present
      end
    end
  end

  # --- Скоупы ---
  describe "scopes" do
    describe ".active" do
      let!(:active_report) { create(:user_report, :active) }
      let!(:inactive_report) { create(:user_report, :inactive) }

      it "returns only active reports" do
        expect(described_class.active).to include(active_report)
        expect(described_class.active).not_to include(inactive_report)
      end
    end

    describe ".inactive" do
      let!(:active_report) { create(:user_report, :active) }
      let!(:inactive_report) { create(:user_report, :inactive) }

      it "returns only inactive reports" do
        expect(described_class.inactive).to include(inactive_report)
        expect(described_class.inactive).not_to include(active_report)
      end
    end
  end

  # --- Колбэки ---
  describe "callbacks" do
    describe "before_create :generate_uuid" do
      it "generates a UUID as the id on create" do
        report = create(:user_report)
        expect(report.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end
    end
  end

  # --- Фабрика ---
  describe "factory" do
    it "builds a valid report" do
      expect(build(:user_report)).to be_valid
    end

    it "creates a report" do
      expect { create(:user_report) }.to change(described_class, :count).by(1)
    end
  end

  # --- Трейты ---
  describe "traits" do
    it "builds an active report" do
      report = build(:user_report, :active)
      expect(report.is_active).to be true
    end

    it "builds an inactive report" do
      report = build(:user_report, :inactive)
      expect(report.is_active).to be false
    end
  end
end
