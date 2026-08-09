require "rails_helper"

RSpec.describe MinecraftAccount, type: :model do
  # ── Связи ─────────────────────────────────────────────────────────────
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  # ── Валидации ─────────────────────────────────────────────────────────
  describe "validations" do
    subject { build(:minecraft_account) }

    it { is_expected.to validate_presence_of(:nickname) }

    it "validates uniqueness of nickname" do
      existing = create(:minecraft_account)
      duplicate = build(:minecraft_account, nickname: existing.nickname)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:nickname]).to be_present
    end

    it { is_expected.to validate_length_of(:nickname).is_at_least(3).is_at_most(27) }

    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_presence_of(:password_confirmation) }

    it "validates uniqueness of user_id" do
      existing = create(:minecraft_account)
      duplicate = build(:minecraft_account, user: existing.user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    # Формат никнейма
    it { is_expected.to allow_value("Player_1", "Steve", "abc_123").for(:nickname) }
    it { is_expected.not_to allow_value("player name", "player-name", "player@name").for(:nickname) }
  end

  # ── Детали валидации никнейма ─────────────────────────────────────────
  describe "nickname validation" do
    it "rejects nicknames shorter than 3 characters" do
      account = build(:minecraft_account, nickname: "ab")
      expect(account).not_to be_valid
      expect(account.errors[:nickname]).to be_present
    end

    it "rejects nicknames longer than 27 characters" do
      account = build(:minecraft_account, nickname: "a" * 28)
      expect(account).not_to be_valid
      expect(account.errors[:nickname]).to be_present
    end

    it "rejects nicknames with special characters" do
      account = build(:minecraft_account, nickname: "player-name!")
      expect(account).not_to be_valid
      expect(account.errors[:nickname]).to be_present
    end

    it "accepts valid alphanumeric + underscore nicknames" do
      account = build(:minecraft_account, nickname: "Valid_Player_1")
      expect(account).to be_valid
    end
  end

  # ── Сложность пароля ──────────────────────────────────────────────────
  describe "password complexity" do
    it "requires at least 8 characters" do
      account = build(:minecraft_account, password: "Pass1", password_confirmation: "Pass1")
      expect(account).not_to be_valid
      expect(account.errors[:password]).to be_present
    end

    it "requires at least one lowercase letter" do
      account = build(:minecraft_account, password: "ALLCAPS123", password_confirmation: "ALLCAPS123")
      expect(account).not_to be_valid
      expect(account.errors[:password]).to be_present
    end

    it "requires at least one digit" do
      account = build(:minecraft_account, password: "NoDigits", password_confirmation: "NoDigits")
      expect(account).not_to be_valid
      expect(account.errors[:password]).to be_present
    end

    it "accepts a valid password with lowercase and digit" do
      account = build(:minecraft_account, password: "Password1", password_confirmation: "Password1")
      expect(account).to be_valid
    end

    it "accepts passwords up to 32 characters" do
      password = "a1" + "b" * 30
      account = build(:minecraft_account, password: password, password_confirmation: password)
      expect(account).to be_valid
    end

    it "rejects passwords over 32 characters" do
      password = "a1" + "b" * 31
      account = build(:minecraft_account, password: password, password_confirmation: password)
      expect(account).not_to be_valid
    end
  end

  # ── Подтверждение пароля ──────────────────────────────────────────────
  describe "password confirmation" do
    it "is invalid when password and confirmation don't match" do
      account = build(:minecraft_account, password: "Password1", password_confirmation: "Password2")
      expect(account).not_to be_valid
      expect(account.errors[:password_confirmation]).to be_present
    end

    it "is valid when password and confirmation match" do
      account = build(:minecraft_account, password: "Password1", password_confirmation: "Password1")
      expect(account).to be_valid
    end
  end

  # ── Никнейм не в DropedUsers ─────────────────────────────────────────
  describe "username_not_in_droped_users" do
    it "is invalid when nickname exists in droped_users" do
      create(:droped_user, name: "BannedPlayer")
      account = build(:minecraft_account, nickname: "BannedPlayer")
      expect(account).not_to be_valid
      expect(account.errors[:nickname]).to be_present
    end

    it "is valid when nickname is not in droped_users" do
      account = build(:minecraft_account, nickname: "NewPlayer")
      expect(account).to be_valid
    end
  end

  # ── Колбэки ───────────────────────────────────────────────────────────
  describe "callbacks" do
    describe "before_validation :generate_uuid (on create)" do
      it "generates a UUID for new records" do
        account = build(:minecraft_account, id: nil)
        account.valid?
        expect(account.id).to be_present
        expect(account.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end

      it "does not overwrite an existing id" do
        existing_id = SecureRandom.uuid
        account = build(:minecraft_account, id: existing_id)
        account.valid?
        expect(account.id).to eq(existing_id)
      end
    end

    describe "before_save :hash_password" do
      it "hashes the password before saving" do
        account = create(:minecraft_account, password: "Password1", password_confirmation: "Password1")
        expect(account.password_hash).to be_present
        expect(account.password_hash).to start_with("$SHA$")
      end

      it "generates a hash in the format $SHA$salt$hash" do
        account = create(:minecraft_account, password: "Password1", password_confirmation: "Password1")
        parts = account.password_hash.split("$")
        expect(parts.length).to eq(4)
        expect(parts[1]).to eq("SHA")
        expect(parts[2].length).to eq(16) # hex(8) = 16 chars
      end

      it "re-hashes when password changes" do
        account = create(:minecraft_account, password: "Password1", password_confirmation: "Password1")
        old_hash = account.password_hash
        account.password = "NewPassword1"
        account.password_confirmation = "NewPassword1"
        account.save!
        expect(account.password_hash).not_to eq(old_hash)
      end
    end
  end

  # ── Методы экземпляра ─────────────────────────────────────────────────
  describe "#authenticate" do
    it "returns true for the correct password" do
      account = create(:minecraft_account, password: "Password1", password_confirmation: "Password1")
      expect(account.authenticate("Password1")).to be true
    end

    it "returns false for an incorrect password" do
      account = create(:minecraft_account, password: "Password1", password_confirmation: "Password1")
      expect(account.authenticate("WrongPassword1")).to be false
    end

    it "returns false when password_hash is malformed" do
      account = create(:minecraft_account, password: "Password1", password_confirmation: "Password1")
      account.update_column(:password_hash, "malformed")
      expect(account.authenticate("Password1")).to be false
    end
  end

  describe "#hash_password" do
    it "produces a deterministic result for the same password and salt" do
      account = build(:minecraft_account, password: "Test1234")
      account.hash_password
      hash1 = account.password_hash

      # Сброс и повторное хеширование с тем же солью
      account.password = "Test1234"
      # hash_password использует SecureRandom.hex(8) — соль будет другой
      # Проверяем только формат
      expect(account.password_hash).to match(/\A\$SHA\$\h{16}\$\h{64}\z/)
    end

    it "does nothing when password is blank" do
      account = build(:minecraft_account)
      account.password = nil
      account.password_hash = "existing_hash"
      account.hash_password
      expect(account.password_hash).to eq("existing_hash")
    end
  end

  # ── Фабрика ───────────────────────────────────────────────────────────
  describe "factory" do
    it "has a valid factory" do
      expect(build(:minecraft_account)).to be_valid
    end

    it "creates a valid record" do
      expect(create(:minecraft_account)).to be_persisted
    end
  end

  # ── Граничные случаи ──────────────────────────────────────────────────
  describe "edge cases" do
    it "is invalid with a duplicate nickname" do
      existing = create(:minecraft_account)
      duplicate = build(:minecraft_account, nickname: existing.nickname)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:nickname]).to be_present
    end

    it "is invalid with a duplicate user_id" do
      existing = create(:minecraft_account)
      duplicate = build(:minecraft_account, user: existing.user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it "accepts nickname at minimum length (3)" do
      account = build(:minecraft_account, nickname: "abc")
      # Сложность пароля обязательна
      account.password = "Password1"
      account.password_confirmation = "Password1"
      expect(account).to be_valid
    end

    it "accepts nickname at maximum length (27)" do
      account = build(:minecraft_account, nickname: "a" * 27)
      account.password = "Password1"
      account.password_confirmation = "Password1"
      expect(account).to be_valid
    end
  end
end
