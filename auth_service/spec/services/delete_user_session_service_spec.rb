# Переменные окружения до загрузки Rails
ENV["DISCORD_CLIENT_ID"] ||= "test"
ENV["DISCORD_CLIENT_SECRET"] ||= "test"
ENV["GOOGLE_CLIENT_ID"] ||= "test"
ENV["GOOGLE_CLIENT_SECRET"] ||= "test"
ENV["MINECRAFT_SERVICE_URL"] ||= "http://minecraft-service.test"
ENV["INTER_SERVICE_API_KEY"] ||= "test-key"
ENV["WEB_SERVICE_URL"] ||= "http://web-service.test"
ENV["AUTH_SERVICE_URL"] ||= "http://auth-service.test"
ENV["REDIS_URL"] ||= "redis://localhost:6379/0"

require "rails_helper"

RSpec.describe DeleteUserSessionService do
  describe ".call" do
    let(:user_id) { 42 }
    let(:nickname) { "TestPlayer" }
    let(:redis_mock) { instance_double("Redis") }

    before do
      stub_const("REDIS_CLIENT", redis_mock)
    end

    context "when session keys contain matching user_id in JSON format" do
      it "deletes matching session:2:: keys and returns count" do
        session_key = "session:2:abc123"
        session_data = { "user_id" => user_id.to_s, "nickname" => "OtherPlayer" }.to_json

        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")
          .and_yield(session_key)

        allow(redis_mock).to receive(:get).with(session_key).and_return(session_data)
        allow(redis_mock).to receive(:del).with(session_key).and_return(1)

        # Второй проход: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(1)
        expect(redis_mock).to have_received(:del).with(session_key)
      end
    end

    context "when session keys contain matching nickname in JSON format" do
      it "deletes matching session:2:: keys" do
        session_key = "session:2:def456"
        session_data = { "user_id" => "999", "nickname" => nickname }.to_json

        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")
          .and_yield(session_key)

        allow(redis_mock).to receive(:get).with(session_key).and_return(session_data)
        allow(redis_mock).to receive(:del).with(session_key).and_return(1)

        # Второй проход: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(1)
        expect(redis_mock).to have_received(:del).with(session_key)
      end
    end

    context "when session data is not JSON but contains user_id as raw string" do
      it "falls back to raw string matching and deletes the key" do
        session_key = "session:2:raw789"
        raw_data = "\x04\bsome_marshaled_data_with_#{user_id}_inside"

        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")
          .and_yield(session_key)

        allow(redis_mock).to receive(:get).with(session_key).and_return(raw_data)
        allow(redis_mock).to receive(:del).with(session_key).and_return(1)

        # Второй проход: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(1)
        expect(redis_mock).to have_received(:del).with(session_key)
      end
    end

    context "when session data does not match user_id or nickname" do
      it "does not delete the key" do
        session_key = "session:2:unrelated"
        session_data = { "user_id" => "999", "nickname" => "SomeoneElse" }.to_json

        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")
          .and_yield(session_key)

        allow(redis_mock).to receive(:get).with(session_key).and_return(session_data)
        allow(redis_mock).to receive(:del)

        # Второй проход: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(0)
        expect(redis_mock).not_to have_received(:del)
      end
    end

    context "when session key has empty or nil value" do
      it "skips the key without error" do
        session_key = "session:2:empty"

        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")
          .and_yield(session_key)

        allow(redis_mock).to receive(:get).with(session_key).and_return(nil)

        # Второй проход: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        expect {
          described_class.call(user_id: user_id, nickname: nickname)
        }.not_to raise_error
      end

      it "skips keys with empty string values" do
        session_key = "session:2:empty_str"

        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")
          .and_yield(session_key)

        allow(redis_mock).to receive(:get).with(session_key).and_return("")

        # Второй проход: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        expect {
          described_class.call(user_id: user_id, nickname: nickname)
        }.not_to raise_error
      end
    end

    context "второй проход: удаление ключей по паттерну" do
      it "deletes keys matching user_id pattern (excluding session:2:: keys)" do
        # Первый проход: ключей session:2:: нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")

        user_key = "user:session:#{user_id}"
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
          .and_yield(user_key)
        allow(redis_mock).to receive(:del).with(user_key).and_return(1)

        # Шаблон nickname: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(1)
        expect(redis_mock).to have_received(:del).with(user_key)
      end

      it "deletes keys matching nickname pattern (excluding session:2:: keys)" do
        # Первый проход: ключей session:2:: нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")

        # Шаблон user_id: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")

        nick_key = "player:#{nickname}:data"
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")
          .and_yield(nick_key)
        allow(redis_mock).to receive(:del).with(nick_key).and_return(1)

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(1)
        expect(redis_mock).to have_received(:del).with(nick_key)
      end

      it "does not delete session:2:: keys in the second pass" do
        # Первый проход: ключей session:2:: нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")

        # Второй проход даёт ключ session:2:: — guard должен пропустить
        session_key = "session:2::#{user_id}"
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
          .and_yield(session_key)

        # Шаблон nickname: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        allow(redis_mock).to receive(:del)

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(0)
        expect(redis_mock).not_to have_received(:del)
      end
    end

    context "when no keys match" do
      it "returns 0" do
        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(0)
      end
    end

    context "when multiple keys match" do
      it "deletes all matching keys and returns total count" do
        key1 = "session:2:first"
        key2 = "session:2:second"
        key3 = "user:data:#{user_id}"

        data1 = { "user_id" => user_id.to_s }.to_json
        data2 = { "nickname" => nickname }.to_json

        # Первый проход
        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")
          .and_yield(key1)
          .and_yield(key2)

        allow(redis_mock).to receive(:get).with(key1).and_return(data1)
        allow(redis_mock).to receive(:get).with(key2).and_return(data2)
        allow(redis_mock).to receive(:del).with(key1).and_return(1)
        allow(redis_mock).to receive(:del).with(key2).and_return(1)

        # Второй проход
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
          .and_yield(key3)
        allow(redis_mock).to receive(:del).with(key3).and_return(1)

        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(3)
      end
    end

    context "when an error occurs during key processing" do
      it "continues processing remaining keys" do
        key1 = "session:2:error_key"
        key2 = "session:2:good_key"

        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")
          .and_yield(key1)
          .and_yield(key2)

        allow(redis_mock).to receive(:get).with(key1).and_raise(Redis::BaseError.new("connection lost"))
        allow(redis_mock).to receive(:get).with(key2).and_return({ "user_id" => user_id.to_s }.to_json)
        allow(redis_mock).to receive(:del).with(key2).and_return(1)

        # Второй проход: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(1)
        expect(redis_mock).to have_received(:del).with(key2)
      end
    end

    context "when user_id is passed as integer" do
      it "converts to string for comparison" do
        session_key = "session:2:int_test"
        session_data = { "user_id" => user_id.to_s, "nickname" => "Other" }.to_json

        allow(redis_mock).to receive(:scan_each)
          .with(match: "session:2::*")
          .and_yield(session_key)

        allow(redis_mock).to receive(:get).with(session_key).and_return(session_data)
        allow(redis_mock).to receive(:del).with(session_key).and_return(1)

        # Второй проход: ключей нет
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{user_id}*")
        allow(redis_mock).to receive(:scan_each)
          .with(match: "*#{nickname}*")

        result = described_class.call(user_id: user_id, nickname: nickname)

        expect(result).to eq(1)
      end
    end
  end
end
