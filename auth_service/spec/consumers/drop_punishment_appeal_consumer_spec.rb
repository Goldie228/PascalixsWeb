require "rails_helper"

RSpec.describe DropPunishmentAppealConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  before do
    allow(UserDataProducer).to receive(:publish)
    redis_client = double("REDIS_CLIENT")
    allow(redis_client).to receive(:hset)
    allow(redis_client).to receive(:expire)
    allow(redis_client).to receive(:del)
    stub_const("REDIS_CLIENT", redis_client)
    allow(MinecraftAccount).to receive(:find_by).and_return(nil)
  end

  # Хелпер: мок Karafka-сообщения
  def build_message(payload)
    double("Message", payload: payload)
  end

  # Хелпер: привязка сообщений к потребителю
  def stub_messages(*payloads)
    messages = payloads.map { |p| build_message(p) }
    allow(consumer).to receive(:messages).and_return(messages)
  end

  let(:user) { create(:user) }
  let(:bad_user) { create(:user) }
  let(:reason) { create(:punishment_reason, :ban) }
  let(:punishment) do
    create(:users_punishment,
           user: user,
           bad_user: bad_user,
           punishment_reason: reason,
           type: "ban")
  end

  describe "#consume" do
    context "when appeal exists for the punishment" do
      let!(:appeal) do
        create(:user_punishment_appeal,
               punishment: punishment,
               status: "pending",
               user_message: "Please remove this ban")
      end

      it "destroys the appeal" do
        stub_messages({ "id" => punishment.id })
        consumer.consume

        expect(UserPunishmentAppeal.exists?(appeal.id)).to be false
      end

      it "logs the deletion" do
        stub_messages({ "id" => punishment.id })

        allow(Rails.logger).to receive(:info)
        consumer.consume

        expect(Rails.logger).to have_received(:info).with(/Обращение удалено/).at_least(:once)
      end
    end

    context "when no appeal exists for the punishment" do
      it "does not raise an error" do
        punishment
        stub_messages({ "id" => punishment.id })

        expect { consumer.consume }.not_to raise_error
      end

      it "logs that no appeal was found" do
        punishment
        stub_messages({ "id" => punishment.id })

        allow(Rails.logger).to receive(:info)
        consumer.consume

        expect(Rails.logger).to have_received(:info).with(/Нет обращения для удаления/).at_least(:once)
      end
    end

    context "when punishment does not exist" do
      it "skips the message silently" do
        stub_messages({ "id" => "nonexistent-id" })

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "with nested payload structure" do
      let!(:appeal) do
        create(:user_punishment_appeal, punishment: punishment)
      end

      it "extracts id from payload.payload" do
        stub_messages({ "payload" => { "id" => punishment.id } })
        consumer.consume

        expect(UserPunishmentAppeal.exists?(appeal.id)).to be false
      end

      it "falls back to top-level payload when nested is absent" do
        stub_messages({ "id" => punishment.id })
        consumer.consume

        expect(UserPunishmentAppeal.exists?(appeal.id)).to be false
      end
    end

    context "with multiple messages" do
      let(:punishment2) do
        create(:users_punishment,
               user: user,
               bad_user: bad_user,
               punishment_reason: reason,
               type: "ban")
      end
      let!(:appeal1) { create(:user_punishment_appeal, punishment: punishment) }
      let!(:appeal2) { create(:user_punishment_appeal, punishment: punishment2) }

      it "processes all messages" do
        stub_messages(
          { "id" => punishment.id },
          { "id" => punishment2.id }
        )
        consumer.consume

        expect(UserPunishmentAppeal.exists?(appeal1.id)).to be false
        expect(UserPunishmentAppeal.exists?(appeal2.id)).to be false
      end
    end

    context "when an error occurs" do
      it "rescues and logs the error" do
        allow(UsersPunishment).to receive(:find_by).and_raise(StandardError, "DB error")
        stub_messages({ "id" => "some-id" })

        expect(Rails.logger).to receive(:error).with(/Ошибка при удалении обращения/)
        consumer.consume
      end

      it "continues processing after an error" do
        punishment
        call_count = 0
        allow(UsersPunishment).to receive(:find_by) do
          call_count += 1
          raise StandardError, "DB error" if call_count == 1

          punishment
        end

        stub_messages({ "id" => "bad-id" }, { "id" => punishment.id })

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "with nil id in payload" do
      it "handles gracefully" do
        stub_messages({ "id" => nil })

        expect { consumer.consume }.not_to raise_error
      end
    end
  end
end
