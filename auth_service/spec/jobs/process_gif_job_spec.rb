require "rails_helper"

RSpec.describe ProcessGifJob, type: :job do
  let(:user) do
    User.skip_email_validation { create(:user) }
  end
  let(:discord_account) { user.discord_account }

  before do
    # Предотвращаем вызовы ClickHouse из публикации событий
    allow(UserDataProducer).to receive(:publish)
    # Разрешаем logger принимать сообщения (spy)
    allow(Rails.logger).to receive(:info).and_call_original
    allow(Rails.logger).to receive(:error).and_call_original
    allow(Rails.logger).to receive(:warn).and_call_original
  end

  describe "#perform" do
    context "when DiscordAvatar exists with a GIF attached" do
      let(:discord_avatar) { create(:discord_avatar, :with_gif_file, discord_account: discord_account) }
      let(:gif_cropper_double) { instance_double(GifCropperService) }

      before do
        allow(GifCropperService).to receive(:new).and_return(gif_cropper_double)
        allow(gif_cropper_double).to receive(:process_and_replace)
      end

      it "calls GifCropperService with a file attachment" do
        described_class.new.perform(discord_avatar.id)

        expect(GifCropperService).to have_received(:new).with(instance_of(ActiveStorage::Attached::One))
      end

      it "processes and replaces the GIF" do
        described_class.new.perform(discord_avatar.id)

        expect(gif_cropper_double).to have_received(:process_and_replace)
      end

      it "logs processing start" do
        described_class.new.perform(discord_avatar.id)

        expect(Rails.logger).to have_received(:info).with(/Processing GIF for DiscordAvatar/).at_least(:once)
      end

      it "logs successful completion" do
        described_class.new.perform(discord_avatar.id)

        expect(Rails.logger).to have_received(:info).with(/Job completed successfully/).at_least(:once)
      end
    end

    context "when DiscordAvatar has no file attached" do
      let(:discord_avatar) { create(:discord_avatar, discord_account: discord_account) }

      it "logs an error about missing file" do
        described_class.new.perform(discord_avatar.id)

        expect(Rails.logger).to have_received(:error).with(/No file attached to DiscordAvatar/).at_least(:once)
      end

      it "does not call GifCropperService" do
        expect(GifCropperService).not_to receive(:new)
        described_class.new.perform(discord_avatar.id)
      end
    end

    context "when DiscordAvatar does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          described_class.new.perform("nonexistent-uuid")
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when GifCropperService raises an error" do
      let(:discord_avatar) { create(:discord_avatar, :with_gif_file, discord_account: discord_account) }
      let(:gif_cropper_double) { instance_double(GifCropperService) }

      before do
        allow(GifCropperService).to receive(:new).and_return(gif_cropper_double)
        allow(gif_cropper_double).to receive(:process_and_replace)
          .and_raise(RuntimeError.new("ImageMagick processing failed"))
      end

      it "logs the error" do
        expect {
          described_class.new.perform(discord_avatar.id)
        }.to raise_error(RuntimeError, /ImageMagick processing failed/)

        expect(Rails.logger).to have_received(:error).with(/ProcessGifJob Error/).at_least(:once)
      end

      it "re-raises the error" do
        expect {
          described_class.new.perform(discord_avatar.id)
        }.to raise_error(RuntimeError)
      end
    end

    context "with ActiveJob test adapter" do
      let(:discord_avatar) { create(:discord_avatar, :with_gif_file, discord_account: discord_account) }

      it "enqueues the job to the default queue" do
        expect {
          described_class.perform_later(discord_avatar.id)
        }.to have_enqueued_job(described_class).with(discord_avatar.id).on_queue("default")
      end

      it "can be tested with perform_now" do
        gif_cropper_double = instance_double(GifCropperService)
        allow(GifCropperService).to receive(:new).and_return(gif_cropper_double)
        allow(gif_cropper_double).to receive(:process_and_replace)

        expect {
          described_class.perform_now(discord_avatar.id)
        }.not_to raise_error
      end
    end
  end
end
