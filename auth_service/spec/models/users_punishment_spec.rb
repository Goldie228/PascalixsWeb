require "rails_helper"

RSpec.describe UsersPunishment, type: :model do
  # --- Связи ---
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:bad_user).class_name("User") }
    it { is_expected.to belong_to(:punishment_reason) }
  end

  # --- Делегирования ---
  describe "delegations" do
    let(:punishment) { create(:users_punishment) }

    it "delegates description to punishment_reason with prefix" do
      expect(punishment.reason_description).to eq(punishment.punishment_reason.description)
    end

    it "delegates rule_number to punishment_reason with prefix" do
      expect(punishment.punishment_reason_rule_number).to eq(punishment.punishment_reason.rule_number)
    end

    it "delegates price to punishment_reason with prefix" do
      expect(punishment.punishment_reason_price).to eq(punishment.punishment_reason.price)
    end
  end

  # --- Валидации ---
  describe "validations" do
    subject { build(:users_punishment) }

    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:bad_user) }
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_presence_of(:issued_at) }
    it { is_expected.to validate_presence_of(:punishment_reason) }

    it { is_expected.to validate_inclusion_of(:type).in_array(%w[ban mute]).with_message(/недопустимый тип/) }
  end

  # --- Кастомная валидация: punishment_type_matches_reason ---
  describe "#punishment_type_matches_reason" do
    it "is invalid when type does not match punishment_reason type" do
      reason = create(:punishment_reason, :mute)
      punishment = build(:users_punishment, type: "ban", punishment_reason: reason)
      # Перезаписываем after(:build) колбэк синхронизации типа
      punishment.type = "ban"
      expect(punishment).not_to be_valid
      expect(punishment.errors[:punishment_reason]).to be_present
    end

    it "is valid when type matches punishment_reason type" do
      punishment = build(:users_punishment, :ban)
      expect(punishment).to be_valid
    end
  end

  # --- Фабрика ---
  describe "factory" do
    it "builds a valid punishment" do
      expect(build(:users_punishment)).to be_valid
    end

    it "creates a punishment" do
      expect { create(:users_punishment) }.to change(described_class, :count).by(1)
    end
  end

  # --- Трейты ---
  describe "traits" do
    it "builds a ban punishment" do
      punishment = build(:users_punishment, :ban)
      expect(punishment.type).to eq("ban")
      expect(punishment.punishment_reason.punishment_type).to eq("ban")
    end

    it "builds a mute punishment" do
      punishment = build(:users_punishment, :mute)
      expect(punishment.type).to eq("mute")
      expect(punishment.punishment_reason.punishment_type).to eq("mute")
    end

    it "builds an expired punishment" do
      punishment = build(:users_punishment, :expired)
      expect(punishment.active).to be false
      expect(punishment.expires_at).to be < Time.current
    end

    it "builds a permanent punishment" do
      punishment = build(:users_punishment, :permanent)
      expect(punishment.duration).to be_nil
      expect(punishment.expires_at).to be_nil
    end
  end

  # --- Константа VALID_TYPES ---
  describe "VALID_TYPES" do
    it "contains ban and mute" do
      expect(described_class::VALID_TYPES).to match_array(%w[ban mute])
    end
  end

  # --- Колбэк after_commit (обновление Redis) ---
  describe "after_commit callback" do
    it "attempts to update Redis data on create" do
      # Заглушка внешних зависимостей
      redis_client = double("REDIS_CLIENT")
      allow(redis_client).to receive(:hset)
      allow(redis_client).to receive(:expire)
      allow(redis_client).to receive(:del)
      stub_const("REDIS_CLIENT", redis_client)

      allow(MinecraftAccount).to receive(:find_by).and_return(nil)
      allow(UserDataProducer).to receive(:publish)

      # В Rails 8.1 с транзакционными фикстурами after_commit срабатывает во время create
      punishment = create(:users_punishment)
      expect(redis_client).to have_received(:hset).with(
        "punishments:#{punishment.bad_user_id}", "data", anything
      )
    end
  end

  # --- inheritance_column отключён ---
  describe "STI disabled" do
    it "does not use Single Table Inheritance" do
      expect(described_class.inheritance_column).to eq("_type_disabled")
    end
  end
end
