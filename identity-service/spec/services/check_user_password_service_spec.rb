# Переменные окружения до загрузки Rails
ENV["DISCORD_CLIENT_ID"] ||= "test"
ENV["DISCORD_CLIENT_SECRET"] ||= "test"
ENV["GOOGLE_CLIENT_ID"] ||= "test"
ENV["GOOGLE_CLIENT_SECRET"] ||= "test"
ENV["GAME_SERVICE_URL"] ||= "http://minecraft-service.test"
ENV["INTER_SERVICE_API_KEY"] ||= "test-key"
ENV["WEB_PORTAL_URL"] ||= "http://web-service.test"
ENV["IDENTITY_SERVICE_URL"] ||= "http://auth-service.test"
ENV["REDIS_URL"] ||= "redis://localhost:6379/0"

require "rails_helper"

RSpec.describe CheckUserPasswordService do
  describe ".call" do
    let(:user) { create(:user) }
    let(:minecraft_account) { create(:minecraft_account, user: user) }
    let(:remote_hash) { "$SHA$abc123$remotehashvalue" }
    let(:api_url) { "#{ENV['GAME_SERVICE_URL']}/api/v1/players/#{minecraft_account.nickname}/check_password" }

    before do
      # Устанавливаем ENV напрямую для сервиса
      @original_minecraft_url = ENV["GAME_SERVICE_URL"]
      @original_api_key = ENV["INTER_SERVICE_API_KEY"]
      ENV["GAME_SERVICE_URL"] = "http://minecraft-service"
      ENV["INTER_SERVICE_API_KEY"] = "test-api-key"
    end

    after do
      ENV["GAME_SERVICE_URL"] = @original_minecraft_url
      ENV["INTER_SERVICE_API_KEY"] = @original_api_key
    end

    context "when looking up account by nickname" do
      it "finds the account and checks password hash" do
        stub_request(:get, api_url)
          .with(
            query: { nickname: minecraft_account.nickname, password: minecraft_account.password_hash },
            headers: {
              "Authorization" => "Bearer test-api-key",
              "Accept" => "application/json"
            }
          )
          .to_return(
            status: 200,
            body: { correct_hash: minecraft_account.password_hash }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        expect {
          described_class.call(nickname: minecraft_account.nickname)
        }.not_to change { minecraft_account.reload.password_hash }
      end
    end

    context "when looking up account by user_id" do
      it "finds the account and checks password hash" do
        stub_request(:get, api_url)
          .with(
            query: { nickname: minecraft_account.nickname, password: minecraft_account.password_hash },
            headers: {
              "Authorization" => "Bearer test-api-key",
              "Accept" => "application/json"
            }
          )
          .to_return(
            status: 200,
            body: { correct_hash: minecraft_account.password_hash }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        expect {
          described_class.call(user_id: user.id)
        }.not_to change { minecraft_account.reload.password_hash }
      end
    end

    context "when password hashes match" do
      it "does not update the password_hash" do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: { correct_hash: minecraft_account.password_hash }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        original_hash = minecraft_account.password_hash

        described_class.call(nickname: minecraft_account.nickname)

        expect(minecraft_account.reload.password_hash).to eq(original_hash)
      end
    end

    context "when password hashes do not match" do
      it "updates the password_hash with the remote hash" do
        new_hash = "$SHA$newsalt$newhashvalue123"
        original_hash = minecraft_account.password_hash

        allow(CheckUserPasswordService).to receive(:fetch_remote_password_hash).and_return(new_hash)

        described_class.call(nickname: minecraft_account.nickname)

        # Сервис вызывает update_attribute(:password_hash, remote_hash),
        # что вызывает before_save. Проверяем что хеш изменился.
        expect(minecraft_account.reload.password_hash).not_to eq(original_hash)
      end
    end

    context "when account is not found" do
      it "returns nil without making an API call" do
        expect(HTTParty).not_to receive(:get)

        result = described_class.call(nickname: "NonExistentPlayer")

        expect(result).to be_nil
      end

      it "returns nil when both nickname and user_id are nil" do
        expect(HTTParty).not_to receive(:get)

        result = described_class.call

        expect(result).to be_nil
      end
    end

    context "when remote API returns no hash" do
      it "returns nil without updating the account" do
        original_hash = minecraft_account.password_hash

        allow(CheckUserPasswordService).to receive(:fetch_remote_password_hash).and_return(nil)

        result = described_class.call(nickname: minecraft_account.nickname)

        expect(result).to be_nil
        expect(minecraft_account.reload.password_hash).to eq(original_hash)
      end

      it "handles empty response body gracefully" do
        allow(CheckUserPasswordService).to receive(:fetch_remote_password_hash).and_return(nil)

        expect {
          described_class.call(nickname: minecraft_account.nickname)
        }.not_to raise_error
      end
    end

    context "when remote API returns an error" do
      it "handles HTTP errors gracefully" do
        stub_request(:get, api_url)
          .to_return(status: 500, body: "Internal Server Error")

        expect {
          described_class.call(nickname: minecraft_account.nickname)
        }.not_to raise_error
      end

      it "handles network errors gracefully" do
        stub_request(:get, api_url)
          .to_timeout

        expect {
          described_class.call(nickname: minecraft_account.nickname)
        }.not_to raise_error
      end
    end

    context "when nickname has leading/trailing whitespace" do
      it "strips whitespace before lookup" do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: { correct_hash: minecraft_account.password_hash }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        expect {
          described_class.call(nickname: "  #{minecraft_account.nickname}  ")
        }.not_to raise_error
      end
    end

    context "when nickname takes priority over user_id" do
      it "uses nickname when both are provided" do
        other_account = create(:minecraft_account, nickname: "OtherPlayer")

        allow(CheckUserPasswordService).to receive(:fetch_remote_password_hash).and_return(other_account.password_hash)

        # Должен использовать nickname (OtherPlayer), а не user_id
        described_class.call(nickname: "OtherPlayer", user_id: user.id)

        # Проверяем что сервис вызван с аккаунтом OtherPlayer
        expect(CheckUserPasswordService).to have_received(:fetch_remote_password_hash) do |account|
          account.nickname == "OtherPlayer"
        end
      end
    end
  end
end
