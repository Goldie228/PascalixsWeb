require "rails_helper"

RSpec.describe DiscordAccount, type: :model do
  # Заглушка внешних продюсеров
  before do
    allow(UserDataProducer).to receive(:publish)
    allow(DownloadDiscordAvatarJob).to receive(:perform_later)
  end

  # ── Связи ─────────────────────────────────────────────────────────────
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:discord_avatars).dependent(:destroy) }
  end

  # ── Валидации ─────────────────────────────────────────────────────────
  describe "validations" do
    subject { build(:discord_account) }

    it { is_expected.to validate_presence_of(:discord_id) }

    it "validates uniqueness of discord_id" do
      existing = create(:discord_account)
      duplicate = build(:discord_account, discord_id: existing.discord_id)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:discord_id]).to be_present
    end

    it { is_expected.to validate_presence_of(:username) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to allow_value("user@example.com").for(:email) }
    it { is_expected.to allow_value("user+tag@example.co.uk").for(:email) }
    it { is_expected.not_to allow_value("invalid-email").for(:email) }
    it { is_expected.not_to allow_value("user@").for(:email) }
    it { is_expected.not_to allow_value("@example.com").for(:email) }

    it { is_expected.to validate_presence_of(:avatar) }

    it "validates uniqueness of user_id" do
      existing = create(:discord_account)
      duplicate = build(:discord_account, user: existing.user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end
  end

  # ── Валидация дискриминатора ──────────────────────────────────────────
  describe "discriminator validation" do
    it "allows blank discriminator (presence skipped when blank)" do
      account = build(:discord_account, discriminator: nil)
      account.valid?
      expect(account.errors[:discriminator]).to be_empty
    end

    it "allows a valid discriminator" do
      account = build(:discord_account, discriminator: "1234")
      account.valid?
      expect(account.errors[:discriminator]).to be_empty
    end
  end

  # ── Колбэки ───────────────────────────────────────────────────────────
  describe "callbacks" do
    describe "before_validation :generate_uuid (on create)" do
      it "generates a UUID for new records" do
        account = build(:discord_account, id: nil)
        account.valid?
        expect(account.id).to be_present
        expect(account.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end

      it "does not overwrite an existing id" do
        existing_id = SecureRandom.uuid
        account = build(:discord_account, id: existing_id)
        account.valid?
        expect(account.id).to eq(existing_id)
      end
    end

    describe "after_commit :publish_user_event (on update)" do
      it "publishes user data on update" do
        account = create(:discord_account)
        expect(UserDataProducer).to receive(:publish).with(account.user)
        account.update!(username: "new_username")
        # Ручной вызов after_update_commit
        trigger_after_update_commit(account)
      end

      it "does not publish on create" do
        account = create(:discord_account)
        # Expectation после create — чтобы не сработал after_create_commit
        expect(UserDataProducer).not_to receive(:publish)
        # Ручной вызов after_create_commit (publish не должен вызываться)
        trigger_after_create_commit(account)
      end
    end
  end

  # ── Методы экземпляра ─────────────────────────────────────────────────
  describe "#add_avatar" do
    it "creates a discord_avatar record" do
      account = create(:discord_account)
      expect {
        account.add_avatar("https://cdn.discordapp.com/avatars/123/new_avatar.png")
      }.to change(DiscordAvatar, :count).by(1)
    end

    it "creates avatar with correct attributes" do
      account = create(:discord_account)
      url = "https://cdn.discordapp.com/avatars/123/new_avatar.png"
      account.add_avatar(url)
      avatar = account.discord_avatars.last
      expect(avatar.original_url).to eq(url)
      expect(avatar.status).to eq("approved")
    end

    it "enqueues DownloadDiscordAvatarJob" do
      account = create(:discord_account)
      url = "https://cdn.discordapp.com/avatars/123/new_avatar.png"
      expect(DownloadDiscordAvatarJob).to receive(:perform_later)
      account.add_avatar(url)
    end
  end

  # ── Фабрика ───────────────────────────────────────────────────────────
  describe "factory" do
    it "has a valid factory" do
      expect(build(:discord_account)).to be_valid
    end
  end

  # ── Граничные случаи ──────────────────────────────────────────────────
  describe "edge cases" do
    it "is invalid with a duplicate discord_id" do
      existing = create(:discord_account)
      duplicate = build(:discord_account, discord_id: existing.discord_id)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:discord_id]).to be_present
    end

    it "is invalid with a duplicate user_id" do
      existing = create(:discord_account)
      duplicate = build(:discord_account, user: existing.user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it "is invalid with malformed email" do
      account = build(:discord_account, email: "not-an-email")
      expect(account).not_to be_valid
      expect(account.errors[:email]).to be_present
    end
  end
end
