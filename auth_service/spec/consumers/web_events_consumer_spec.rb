require "rails_helper"

RSpec.describe WebEventsConsumer do
  subject(:consumer) { described_class.new }

  # Заглушка with_deduplication — метода нет в кодовой базе
  # Определяем на классе для RSpec verify_partial_doubles
  before(:all) do
    WebEventsConsumer.class_eval do
      def with_deduplication(_key)
        yield
      end
    end
  end

  after(:all) do
    WebEventsConsumer.class_eval do
      remove_method :with_deduplication if method_defined?(:with_deduplication)
    end
  end

  # Мок Karafka-сообщения с JSON-строкой в payload
  def build_message(payload_hash, message_id: "msg-001")
    double(
      "Karafka::Messages::Message",
      payload: payload_hash.to_json,
      id: message_id
    )
  end

  describe "#consume" do
    context "when event_type is 'page_viewed'" do
      let(:payload) do
        {
          "event_type" => "page_viewed",
          "user_id" => "user-123",
          "page_path" => "/dashboard",
          "timestamp" => "2026-07-21T10:00:00Z"
        }
      end

      it "logs the page view event" do
        message = build_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        expect(Rails.logger).to receive(:info).with(/Просмотр страницы.*user-123.*\/dashboard/)

        consumer.consume
      end

      it "calls with_deduplication with the correct key" do
        message = build_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        expect(consumer).to receive(:with_deduplication).with(
          "web_event:user-123:page_viewed:2026-07-21T10:00:00Z"
        ).and_yield

        consumer.consume
      end
    end

    context "when event_type is 'user_action'" do
      let(:payload) do
        {
          "event_type" => "user_action",
          "user_id" => "user-456",
          "action_type" => "login_attempt",
          "details" => "IP: 192.168.1.1",
          "timestamp" => "2026-07-21T10:05:00Z"
        }
      end

      it "logs the user action event and details" do
        message = build_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        # Consumer логирует два сообщения: тип действия и детали
        expect(Rails.logger).to receive(:info).with(/Действие пользователя.*user-456.*login_attempt/)
        expect(Rails.logger).to receive(:info).with(/Попытка входа.*IP: 192.168.1.1/)

        consumer.consume
      end

      context "with action_type 'profile_view'" do
        let(:payload) do
          {
            "event_type" => "user_action",
            "user_id" => "user-789",
            "action_type" => "profile_view",
            "details" => "Viewed own profile",
            "timestamp" => "2026-07-21T10:10:00Z"
          }
        end

        it "logs the action and profile view details" do
          message = build_message(payload)
          allow(consumer).to receive(:messages).and_return([message])

          expect(Rails.logger).to receive(:info).with(/Действие пользователя.*user-789.*profile_view/)
          expect(Rails.logger).to receive(:info).with(/Просмотр профиля.*Viewed own profile/)

          consumer.consume
        end
      end

      context "with action_type 'settings_changed'" do
        let(:payload) do
          {
            "event_type" => "user_action",
            "user_id" => "user-101",
            "action_type" => "settings_changed",
            "details" => "Changed timezone",
            "timestamp" => "2026-07-21T10:15:00Z"
          }
        end

        it "logs the action and settings change details" do
          message = build_message(payload)
          allow(consumer).to receive(:messages).and_return([message])

          expect(Rails.logger).to receive(:info).with(/Действие пользователя.*user-101.*settings_changed/)
          expect(Rails.logger).to receive(:info).with(/Изменение настроек.*Changed timezone/)

          consumer.consume
        end
      end
    end

    context "when event_type is 'error_occurred'" do
      let(:payload) do
        {
          "event_type" => "error_occurred",
          "user_id" => "user-err",
          "error_type" => "TypeError",
          "error_message" => "Cannot read property of undefined",
          "page_path" => "/settings",
          "timestamp" => "2026-07-21T10:20:00Z"
        }
      end

      it "logs the error with details" do
        message = build_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        expect(Rails.logger).to receive(:error).with(
          /Ошибка во фронтенде.*TypeError.*Cannot read property.*user-err.*\/settings/
        )

        consumer.consume
      end
    end

    context "when event_type is 'performance_metric'" do
      let(:payload) do
        {
          "event_type" => "performance_metric",
          "user_id" => "user-perf",
          "metric_name" => "LCP",
          "value" => "2.5s",
          "page_path" => "/home",
          "timestamp" => "2026-07-21T10:25:00Z"
        }
      end

      it "logs the performance metric" do
        message = build_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        expect(Rails.logger).to receive(:info).with(
          /Метрика производительности.*LCP.*2\.5s.*user-perf.*\/home/
        )

        consumer.consume
      end
    end

    context "when event_type is unknown" do
      let(:payload) do
        {
          "event_type" => "unknown_event",
          "user_id" => "user-unknown",
          "timestamp" => "2026-07-21T10:30:00Z"
        }
      end

      it "logs the unknown event type" do
        message = build_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        expect(Rails.logger).to receive(:info).with(/Неизвестный тип события: unknown_event/)

        consumer.consume
      end
    end

    context "when processing multiple messages" do
      it "processes each message in the batch" do
        payload1 = {
          "event_type" => "page_viewed",
          "user_id" => "user-a",
          "page_path" => "/page1",
          "timestamp" => "2026-07-21T10:00:00Z"
        }
        payload2 = {
          "event_type" => "error_occurred",
          "user_id" => "user-b",
          "error_type" => "NetworkError",
          "error_message" => "Timeout",
          "page_path" => "/page2",
          "timestamp" => "2026-07-21T10:01:00Z"
        }

        messages = [
          build_message(payload1, message_id: "msg-1"),
          build_message(payload2, message_id: "msg-2")
        ]
        allow(consumer).to receive(:messages).and_return(messages)

        expect(Rails.logger).to receive(:info).with(/Просмотр страницы.*user-a/)
        expect(Rails.logger).to receive(:error).with(/NetworkError.*user-b/)

        consumer.consume
      end
    end

    context "when payload is invalid JSON" do
      it "raises JSON::ParserError" do
        message = double(
          "Karafka::Messages::Message",
          payload: "not-valid-json{",
          id: "msg-bad"
        )
        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to raise_error(JSON::ParserError)
      end
    end

    context "when log_message is called" do
      it "logs the payload at debug level" do
        payload = {
          "event_type" => "page_viewed",
          "user_id" => "user-debug",
          "page_path" => "/test",
          "timestamp" => "2026-07-21T10:35:00Z"
        }
        message = build_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        expect(Rails.logger).to receive(:debug).with(/Получено событие от web_service/)

        consumer.consume
      end
    end
  end
end
