require "rails_helper"

# Заглушка для AuthEventsProducer если не определён
unless defined?(AuthEventsProducer)
  class AuthEventsProducer
    def self.user_registered(*args); end
    def self.user_logged_in(*args); end
    def self.user_logged_out(*args); end
    def self.authentication_successful(*args); end
    def self.authentication_failed(*args); end
  end
end

RSpec.describe User, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  # Заглушка внешних продюсеров для избежания побочных эффектов в тестах
  before do
    allow(AuthEventsProducer).to receive(:user_registered)
    allow(AuthEventsProducer).to receive(:user_logged_in)
    allow(AuthEventsProducer).to receive(:user_logged_out)
    allow(AuthEventsProducer).to receive(:authentication_successful)
    allow(AuthEventsProducer).to receive(:authentication_failed)
    allow(UserDataProducer).to receive(:publish)
  end

  # ── Связи ─────────────────────────────────────────────────────────────
  describe "associations" do
    it { is_expected.to belong_to(:role) }

    it { is_expected.to have_one(:discord_account).dependent(:destroy) }
    it { is_expected.to have_one(:minecraft_account).dependent(:destroy) }

    it {
      is_expected.to have_many(:sent_reports)
        .class_name("UserReport")
        .with_foreign_key(:reporter_id)
        .dependent(:destroy)
    }

    it {
      is_expected.to have_many(:received_reports)
        .class_name("UserReport")
        .with_foreign_key(:reported_user_id)
        .dependent(:destroy)
    }

    it {
      is_expected.to have_many(:issued_punishments)
        .class_name("UsersPunishment")
        .with_foreign_key("user_id")
        .dependent(:destroy)
    }

    it {
      is_expected.to have_many(:received_punishments)
        .class_name("UsersPunishment")
        .with_foreign_key("bad_user_id")
        .dependent(:destroy)
    }
  end

  # ── Валидации ─────────────────────────────────────────────────────────
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_length_of(:about_me).is_at_most(250) }

    it { is_expected.to validate_presence_of(:role) }

    context "when about_me exceeds 250 characters" do
      it "is invalid" do
        user = build(:user, about_me: "a" * 251)
        expect(user).not_to be_valid
        expect(user.errors[:about_me]).to be_present
      end
    end

    context "when about_me is blank" do
      it "is valid (allow_blank)" do
        user = build(:user, about_me: "", role: create(:role, :user))
        expect(user).to be_valid
      end
    end

    context "when about_me is nil" do
      it "is valid (allow_blank)" do
        user = build(:user, about_me: nil, role: create(:role, :user))
        expect(user).to be_valid
      end
    end

    # must_have_discord_account пропущен в тестовой среде
    context "must_have_discord_account validation" do
      it "is skipped in test environment" do
        user = build(:user)
        user.discord_account = nil
        # Ошибка discord_account не должна добавляться в тестах
        user.valid?
        expect(user.errors[:base]).to be_empty
      end
    end
  end

  # ── Колбэки ───────────────────────────────────────────────────────────
  describe "callbacks" do
    describe "before_create :assign_default_role" do
      it "assigns default role when role is nil" do
        default_role = create(:role, :user)
        user = build(:user, role: nil)
        user.save!
        expect(user.role).to eq(default_role)
      end

      it "does not override an explicitly assigned role" do
        admin_role = create(:role, :admin)
        user = build(:user, role: admin_role)
        user.save!
        expect(user.role).to eq(admin_role)
      end
    end

    describe "before_save :downcase_email" do
      it "downcases the email on the discord account" do
        user = create(:user, :with_discord_account)
        user.discord_account.update!(email: "TEST@EXAMPLE.COM")
        # Вызываем before_save через обновление пользователя
        user.save!
        expect(user.discord_account.reload.email).to eq("test@example.com")
      end
    end

    describe "after_commit :publish_user_event" do
      it "publishes user data on create" do
        expect(UserDataProducer).to receive(:publish)
        user = create(:user)
        # Ручной вызов after_create_commit
        trigger_after_create_commit(user)
      end

      it "publishes user data on update" do
        user = create(:user)
        expect(UserDataProducer).to receive(:publish)
        user.update!(about_me: "Updated bio")
        # Ручной вызов after_update_commit
        trigger_after_update_commit(user)
      end

      it "calls AuthEventsProducer.user_registered on create" do
        expect(AuthEventsProducer).to receive(:user_registered)
        user = create(:user)
        # Ручной вызов after_create_commit
        trigger_after_create_commit(user)
      end

      it "does not call AuthEventsProducer.user_registered on update" do
        user = create(:user)
        expect(AuthEventsProducer).not_to receive(:user_registered)
        user.update!(about_me: "Updated bio")
        # Ручной вызов after_update_commit
        trigger_after_update_commit(user)
      end
    end
  end

  # ── Методы экземпляра ─────────────────────────────────────────────────
  describe "#role_name" do
    it "returns the role name" do
      role = create(:role, name: "Admin")
      user = create(:user, role: role)
      expect(user.role_name).to eq("Admin")
    end

    it "returns 'User' when role is nil" do
      user = build(:user)
      user.role = nil
      expect(user.role_name).to eq("User")
    end
  end

  describe "#role_color" do
    it "returns the role color" do
      role = create(:role, color: "#FF0000")
      user = create(:user, role: role)
      expect(user.role_color).to eq("#FF0000")
    end

    it "returns default color when role is nil" do
      user = build(:user)
      user.role = nil
      expect(user.role_color).to eq("#A0A0A0")
    end
  end

  describe "#discord_account_data" do
    it "returns a hash with username, avatar, and email" do
      user = create(:user, :with_discord_account)
      data = user.discord_account_data
      expect(data).to include("username", "avatar", "email")
    end

    it "returns empty hash when no discord account" do
      user = build(:user)
      user.discord_account = nil
      expect(user.discord_account_data).to eq({})
    end

    it "excludes nil values" do
      user = build(:user, :with_discord_account)
      user.discord_account.avatar = nil
      data = user.discord_account_data
      expect(data).not_to have_key("avatar")
    end
  end

  describe "#minecraft_account_data" do
    it "returns a hash with nickname and password_hash" do
      user = create(:user, :with_minecraft_account)
      data = user.minecraft_account_data
      expect(data).to include("nickname", "password_hash")
    end

    it "returns empty hash when no minecraft account" do
      user = build(:user)
      user.minecraft_account = nil
      expect(user.minecraft_account_data).to eq({})
    end
  end

  describe "#email / #email=" do
    it "delegates email to discord_account" do
      user = create(:user, :with_discord_account)
      expect(user.email).to eq(user.discord_account.email)
    end

    it "returns empty string when no discord account" do
      user = build(:user)
      user.discord_account = nil
      expect(user.email).to eq("")
    end

    it "sets email on discord_account when one exists" do
      user = create(:user, :with_discord_account)
      user.email = "new@example.com"
      expect(user.discord_account.reload.email).to eq("new@example.com")
    end

    it "builds a discord_account when none exists" do
      user = build(:user)
      user.discord_account = nil
      user.email = "new@example.com"
      expect(user.discord_account).to be_present
      expect(user.discord_account.email).to eq("new@example.com")
    end
  end

  describe "#will_save_change_to_email? / #email_changed?" do
    it "always returns false for will_save_change_to_email?" do
      user = build(:user)
      expect(user.will_save_change_to_email?).to be false
    end

    it "always returns false for email_changed?" do
      user = build(:user)
      expect(user.email_changed?).to be false
    end
  end

  describe "#valid_password?" do
    it "returns false when no minecraft account" do
      user = build(:user)
      user.minecraft_account = nil
      expect(user.valid_password?("password")).to be false
    end

    it "returns true for correct password" do
      user = create(:user, :with_minecraft_account)
      expect(user.valid_password?("Password1")).to be true
    end

    it "returns false for incorrect password" do
      user = create(:user, :with_minecraft_account)
      expect(user.valid_password?("WrongPass1")).to be false
    end
  end

  describe "#password=" do
    it "sets password_hash on minecraft_account via BCrypt" do
      user = create(:user, :with_minecraft_account)
      user.password = "NewPassword1"
      expect(user.minecraft_account.reload.password_hash).to be_present
      expect(user.valid_password?("NewPassword1")).to be true
    end

    it "builds minecraft_account when none exists" do
      user = build(:user)
      user.minecraft_account = nil
      user.password = "NewPassword1"
      expect(user.minecraft_account).to be_present
      expect(user.minecraft_account.password_hash).to be_present
    end
  end

  describe "#password_required?" do
    it "returns false when minecraft_account is absent" do
      user = build(:user)
      user.minecraft_account = nil
      expect(user.password_required?).to be false
    end

    it "returns false when password_hash is present" do
      user = create(:user, :with_minecraft_account)
      expect(user.password_required?).to be false
    end
  end

  describe "#generate_token" do
    it "returns a token hash with token and expires_at" do
      user = create(:user)
      expires = 1.hour.from_now
      result = user.generate_token(expires_at: expires)
      expect(result).to have_key(:token)
      expect(result).to have_key(:expires_at)
      expect(result[:expires_at]).to eq(expires)
    end

    it "encodes user_id in the JWT payload" do
      user = create(:user)
      result = user.generate_token(expires_at: 1.hour.from_now)
      decoded = JWT.decode(result[:token], Rails.application.secret_key_base, true, algorithm: "HS256")
      expect(decoded[0]["user_id"]).to eq(user.id)
    end
  end

  describe "#auth_token" do
    it "returns a valid JWT string" do
      user = create(:user, :with_discord_account)
      token = user.auth_token
      expect(token).to be_a(String)
      decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256")
      expect(decoded[0]["user_id"]).to eq(user.id)
    end

    it "includes cached discord and minecraft data" do
      user = create(:user, :with_discord_account)
      token = user.auth_token
      decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256")
      expect(decoded[0]["cached"]).to have_key("discord")
      expect(decoded[0]["cached"]).to have_key("minecraft")
      expect(decoded[0]["cached"]).to have_key("otp")
    end
  end

  describe "#update_last_auth_time" do
    it "updates consumed_timestep to current time" do
      user = create(:user)
      freeze_time do
        user.update_last_auth_time
        expect(user.consumed_timestep).to eq(Time.current.to_i)
      end
    end
  end

  # ── Классовые методы ──────────────────────────────────────────────────
  describe ".skip_email_validation" do
    it "sets skip_email_validation? to true within the block" do
      User.skip_email_validation do
        expect(User.skip_email_validation?).to be true
      end
    end

    it "resets skip_email_validation? after the block" do
      User.skip_email_validation {}
      expect(User.skip_email_validation?).to be false
    end

    it "resets even if block raises" do
      begin
        User.skip_email_validation { raise "error" }
      rescue RuntimeError
        # ожидаемое значение
      end
      expect(User.skip_email_validation?).to be false
    end
  end

  describe ".skip_email_validation?" do
    it "returns false by default" do
      expect(User.skip_email_validation?).to be false
    end
  end
end
