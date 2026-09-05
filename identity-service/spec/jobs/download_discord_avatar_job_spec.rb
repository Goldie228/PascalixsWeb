require "rails_helper"

RSpec.describe DownloadDiscordAvatarJob, type: :job do
  let(:user) do
    User.skip_email_validation { create(:user) }
  end
  let(:discord_account) { user.discord_account }
  let(:discord_avatar) { create(:discord_avatar, discord_account: discord_account) }
  let(:avatar_url) { "https://cdn.discordapp.com/avatars/123456/abc123.png" }

  before do
    ENV["IDENTITY_SERVICE_URL"] ||= "http://localhost:3000"
    # Предотвращаем вызовы ClickHouse из публикации событий
    allow(UserDataProducer).to receive(:publish)
    # Разрешаем logger принимать сообщения (spy)
    allow(Rails.logger).to receive(:info).and_call_original
    allow(Rails.logger).to receive(:error).and_call_original
    allow(Rails.logger).to receive(:warn).and_call_original
  end

  describe "#perform" do
    context "when parameters are blank" do
      it "returns early when discord_avatar_id is blank" do
        expect { described_class.new.perform(nil, avatar_url) }.not_to raise_error
      end

      it "returns early when avatar_url is blank" do
        expect { described_class.new.perform(discord_avatar.id, nil) }.not_to raise_error
      end

      it "returns early when both params are blank" do
        expect { described_class.new.perform(nil, nil) }.not_to raise_error
      end

      it "returns early when discord_avatar_id is empty string" do
        expect { described_class.new.perform("", avatar_url) }.not_to raise_error
      end
    end

    context "when DiscordAvatar is not found" do
      it "logs a warning and returns without error" do
        described_class.new.perform("nonexistent-id", avatar_url)
        expect(Rails.logger).to have_received(:warn).with(/not found/).at_least(:once)
      end
    end

    context "when DiscordAvatar exists and download succeeds" do
      let(:avatar_file_url) { "http://localhost:3000/rails/active_storage/blobs/test/avatar.png" }

      before do
        # Создаём IO-подобный объект с content_type
        fake_io = StringIO.new("fake image binary data")
        fake_io.define_singleton_method(:content_type) { "image/png" }

        allow(URI).to receive(:open).with(avatar_url).and_return(fake_io)
        allow(Rails.application.routes.url_helpers).to receive(:rails_blob_url).and_return(avatar_file_url)
      end

      it "downloads the avatar and attaches it to discord_avatar" do
        described_class.new.perform(discord_avatar.id, avatar_url)

        discord_avatar.reload
        expect(discord_avatar.file).to be_attached
      end

      it "updates the discord_account avatar URL" do
        described_class.new.perform(discord_avatar.id, avatar_url)

        discord_account.reload
        expect(discord_account.avatar).to eq(avatar_file_url)
      end

      it "makes an HTTP request to the avatar URL" do
        described_class.new.perform(discord_avatar.id, avatar_url)

        expect(URI).to have_received(:open).with(avatar_url)
      end

      it "logs success message" do
        described_class.new.perform(discord_avatar.id, avatar_url)

        expect(Rails.logger).to have_received(:info).with(/Discord avatar updated/).at_least(:once)
      end
    end

    context "when download fails with HTTP error" do
      before do
        allow(URI).to receive(:open).with(avatar_url)
          .and_raise(OpenURI::HTTPError.new("404 Not Found", StringIO.new))
      end

      it "logs the error and does not raise" do
        expect { described_class.new.perform(discord_avatar.id, avatar_url) }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Failed to download Discord avatar/).at_least(:once)
      end

      it "does not attach any file" do
        described_class.new.perform(discord_avatar.id, avatar_url)

        discord_avatar.reload
        expect(discord_avatar.file).not_to be_attached
      end
    end

    context "when save fails with RecordInvalid" do
      before do
        fake_io = StringIO.new("fake image data")
        fake_io.define_singleton_method(:content_type) { "image/png" }
        allow(URI).to receive(:open).with(avatar_url).and_return(fake_io)

        # Делаем save! выбрасывающим RecordInvalid
        allow_any_instance_of(DiscordAvatar).to receive(:save!).and_raise(
          ActiveRecord::RecordInvalid.new(discord_avatar)
        )
      end

      it "logs the error and does not raise" do
        expect { described_class.new.perform(discord_avatar.id, avatar_url) }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Failed to save Discord avatar/).at_least(:once)
      end
    end

    context "when an unexpected error occurs" do
      before do
        allow(URI).to receive(:open).with(avatar_url)
          .and_raise(StandardError.new("Something unexpected"))
      end

      it "logs the unexpected error and does not raise" do
        expect { described_class.new.perform(discord_avatar.id, avatar_url) }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Unexpected error in DownloadDiscordAvatarJob/).at_least(:once)
      end
    end

    context "with WebMock integration" do
      it "does not make real HTTP requests" do
        stub_request(:get, avatar_url)
          .to_return(status: 200, body: "fake image", headers: { "Content-Type" => "image/png" })

        allow(Rails.application.routes.url_helpers).to receive(:rails_blob_url).and_return("http://test/avatar.png")

        # URI.open проходит через OpenURI — WebMock заглушает
        described_class.new.perform(discord_avatar.id, avatar_url)

        discord_avatar.reload
        expect(discord_avatar.file).to be_attached
      end
    end
  end
end
