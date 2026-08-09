require "rails_helper"

RSpec.describe ReportAttachment, type: :model do
  # --- Связи ---
  describe "associations" do
    it { is_expected.to belong_to(:user_report) }
  end

  # --- Валидации ---
  describe "validations" do
    subject { build(:report_attachment) }

    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to validate_presence_of(:content_type) }
    it { is_expected.to validate_presence_of(:file_size) }

    it { is_expected.to validate_inclusion_of(:content_type).in_array(described_class::SUPPORTED_CONTENT_TYPES) }

    it { is_expected.to validate_numericality_of(:file_size).is_less_than_or_equal_to(2.gigabytes) }
  end

  # --- Константа SUPPORTED_CONTENT_TYPES ---
  describe "SUPPORTED_CONTENT_TYPES" do
    it "includes expected types" do
      expect(described_class::SUPPORTED_CONTENT_TYPES).to include(
        "image/jpeg", "image/png", "video/mp4", "application/mp4"
      )
    end

    it "is frozen" do
      expect(described_class::SUPPORTED_CONTENT_TYPES).to be_frozen
    end
  end

  # --- Константа MAX_FILE_SIZE ---
  describe "MAX_FILE_SIZE" do
    it "equals 2 gigabytes" do
      expect(described_class::MAX_FILE_SIZE).to eq(2.gigabytes)
    end
  end

  # --- Колбэки ---
  describe "callbacks" do
    describe "before_create :generate_uuid" do
      it "generates a UUID as the id on create" do
        attachment = create(:report_attachment)
        expect(attachment.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end
    end

    describe "before_validation :normalize_content_type" do
      it "normalizes application/mp4 to video/mp4" do
        attachment = build(:report_attachment, content_type: "application/mp4")
        attachment.valid?
        expect(attachment.content_type).to eq("video/mp4")
      end

      it "does not change other content types" do
        attachment = build(:report_attachment, content_type: "image/jpeg")
        attachment.valid?
        expect(attachment.content_type).to eq("image/jpeg")
      end
    end
  end

  # --- Методы экземпляра ---
  describe "#download_url" do
    it "returns a blob path for the matching attachment" do
      report = create(:user_report)
      attachment_record = create(:report_attachment, user_report: report, filename: "test.jpg")

      # Создаём соответствующее вложение Active Storage
      report.attachments.attach(
        io: StringIO.new("fake image data"),
        filename: "test.jpg",
        content_type: "image/jpeg"
      )

      url = attachment_record.download_url
      expect(url).to be_present
      expect(url).to include("rails/active_storage")
    end
  end

  # --- Фабрика ---
  describe "factory" do
    it "builds a valid report attachment" do
      expect(build(:report_attachment)).to be_valid
    end

    it "creates a report attachment" do
      expect { create(:report_attachment) }.to change(described_class, :count).by(1)
    end
  end

  # --- Трейты ---
  describe "traits" do
    it "builds a JPEG image attachment" do
      attachment = build(:report_attachment, :image_jpeg)
      expect(attachment.content_type).to eq("image/jpeg")
    end

    it "builds a PNG image attachment" do
      attachment = build(:report_attachment, :image_png)
      expect(attachment.content_type).to eq("image/png")
    end

    it "builds a video MP4 attachment" do
      attachment = build(:report_attachment, :video_mp4)
      expect(attachment.content_type).to eq("video/mp4")
    end
  end
end
