require "rails_helper"

RSpec.describe "Factories" do
  # Smoke-тест: проверяем что все фабрики создают валидные объекты
  describe "build (no DB persistence)" do
    it "builds a valid Role" do
      role = build(:role)
      expect(role).to be_valid
    end

    it "builds a valid DropedUser" do
      droped_user = build(:droped_user)
      expect(droped_user).to be_valid
    end

    it "builds a valid User with role" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "builds a valid DiscordAccount" do
      discord_account = build(:discord_account)
      expect(discord_account).to be_valid
    end

    it "builds a valid MinecraftAccount" do
      minecraft_account = build(:minecraft_account)
      expect(minecraft_account).to be_valid
    end

    it "builds a valid PunishmentReason" do
      punishment_reason = build(:punishment_reason)
      expect(punishment_reason).to be_valid
    end

    it "builds a valid UsersPunishment" do
      users_punishment = build(:users_punishment)
      expect(users_punishment).to be_valid
    end

    it "builds a valid UserPunishmentAppeal" do
      user_punishment_appeal = build(:user_punishment_appeal)
      expect(user_punishment_appeal).to be_valid
    end

    it "builds a valid UserReport" do
      user_report = build(:user_report)
      expect(user_report).to be_valid
    end

    it "builds a valid ReportAttachment" do
      report_attachment = build(:report_attachment)
      expect(report_attachment).to be_valid
    end

    it "builds a valid Product" do
      product = build(:product)
      expect(product).to be_valid
    end

    it "builds a valid Purchase" do
      purchase = build(:purchase)
      expect(purchase).to be_valid
    end

    it "builds a valid Gallery" do
      gallery = build(:gallery)
      expect(gallery).to be_valid
    end

    it "builds a valid Photo" do
      photo = build(:photo)
      expect(photo).to be_valid
    end

    it "builds a valid DiscordAvatar" do
      discord_avatar = build(:discord_avatar)
      expect(discord_avatar).to be_valid
    end
  end

  # Тест персистентности: проверяем что все фабрики сохраняются в БД
  describe "create (DB persistence)" do
    it "creates a Role" do
      expect { create(:role) }.to change(Role, :count).by(1)
    end

    it "creates a DropedUser" do
      expect { create(:droped_user) }.to change(DropedUser, :count).by(1)
    end

    it "creates a User with role and discord_account" do
      expect { create(:user) }.to change(User, :count).by(1)
      expect { create(:user) }.to change(Role, :count).by(1)
    end

    it "creates a DiscordAccount" do
      expect { create(:discord_account) }.to change(DiscordAccount, :count).by(1)
    end

    it "creates a MinecraftAccount" do
      expect { create(:minecraft_account) }.to change(MinecraftAccount, :count).by(1)
    end

    it "creates a PunishmentReason" do
      expect { create(:punishment_reason) }.to change(PunishmentReason, :count).by(1)
    end

    it "creates a UsersPunishment" do
      expect { create(:users_punishment) }.to change(UsersPunishment, :count).by(1)
    end

    it "creates a UserPunishmentAppeal" do
      expect { create(:user_punishment_appeal) }.to change(UserPunishmentAppeal, :count).by(1)
    end

    it "creates a UserReport" do
      expect { create(:user_report) }.to change(UserReport, :count).by(1)
    end

    it "creates a ReportAttachment" do
      expect { create(:report_attachment) }.to change(ReportAttachment, :count).by(1)
    end

    it "creates a Product" do
      expect { create(:product) }.to change(Product, :count).by(1)
    end

    it "creates a Purchase" do
      expect { create(:purchase) }.to change(Purchase, :count).by(1)
    end

    it "creates a Gallery" do
      expect { create(:gallery) }.to change(Gallery, :count).by(1)
    end

    it "creates a Photo with attached file" do
      expect { create(:photo) }.to change(Photo, :count).by(1)
    end

    it "creates a DiscordAvatar" do
      expect { create(:discord_avatar) }.to change(DiscordAvatar, :count).by(1)
    end
  end

  # Тест трейтов: проверяем основные трейты
  describe "traits" do
    it "builds a User with minecraft_account trait" do
      user = build(:user, :with_minecraft_account)
      expect(user.minecraft_account).to be_present
    end

    it "builds a User with accounts trait" do
      user = build(:user, :with_accounts)
      expect(user.discord_account).to be_present
      expect(user.minecraft_account).to be_present
    end

    it "builds a ban PunishmentReason" do
      reason = build(:punishment_reason, :ban)
      expect(reason.punishment_type).to eq("ban")
    end

    it "builds a mute PunishmentReason" do
      reason = build(:punishment_reason, :mute)
      expect(reason.punishment_type).to eq("mute")
    end

    it "builds a ban UsersPunishment" do
      punishment = build(:users_punishment, :ban)
      expect(punishment.type).to eq("ban")
    end

    it "builds a mute UsersPunishment" do
      punishment = build(:users_punishment, :mute)
      expect(punishment.type).to eq("mute")
    end

    it "builds a pending UserPunishmentAppeal" do
      appeal = build(:user_punishment_appeal, :pending)
      expect(appeal.status).to eq("pending")
    end

    it "builds an active UserReport" do
      report = build(:user_report, :active)
      expect(report.is_active).to be true
    end

    it "builds an inactive UserReport" do
      report = build(:user_report, :inactive)
      expect(report.is_active).to be false
    end

    it "builds a pass_gift Purchase with target" do
      purchase = build(:purchase, :pass_gift)
      expect(purchase.purchase_type).to eq("pass_gift")
      expect(purchase.target_user_id).to be_present
    end

    it "builds a published Gallery with photos" do
      gallery = create(:gallery, :published)
      expect(gallery.published).to be true
      expect(gallery.photos).not_to be_empty
    end

    it "builds a DiscordAvatar with approved status" do
      avatar = build(:discord_avatar, :approved)
      expect(avatar.status).to eq("approved")
    end
  end
end
