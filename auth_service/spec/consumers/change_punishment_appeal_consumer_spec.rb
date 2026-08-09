require "rails_helper"

RSpec.describe ChangePunishmentAppealConsumer, type: :consumer do
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
    context "when creating a new appeal" do
      it "creates a UserPunishmentAppeal" do
        punishment
        stub_messages({ "id" => punishment.id, "message" => "I apologize" })

        expect { consumer.consume }.to change(UserPunishmentAppeal, :count).by(1)
      end

      it "sets correct attributes on the appeal" do
        punishment
        stub_messages({ "id" => punishment.id, "message" => "Please reconsider" })
        consumer.consume

        appeal = UserPunishmentAppeal.last
        expect(appeal.punishment_id).to eq(punishment.id)
        expect(appeal.user_message).to eq("Please reconsider")
        expect(appeal.status).to eq("pending")
        expect(appeal.admin_comment).to be_nil
        expect(appeal.can_reappeal).to be true
      end

      it "strips whitespace from user message" do
        punishment
        stub_messages({ "id" => punishment.id, "message" => "  hello  " })
        consumer.consume

        expect(UserPunishmentAppeal.last.user_message).to eq("hello")
      end

      it "handles missing message gracefully" do
        punishment
        stub_messages({ "id" => punishment.id })
        expect { consumer.consume }.to change(UserPunishmentAppeal, :count).by(1)

        appeal = UserPunishmentAppeal.last
        expect(appeal).to be_present
        expect(appeal.user_message).to eq("")
      end
    end

    context "when updating an existing appeal" do
      let!(:existing_appeal) do
        create(:user_punishment_appeal,
               punishment: punishment,
               user_message: "Original message",
               status: "rejected",
               admin_comment: "No",
               can_reappeal: false)
      end

      it "updates the existing appeal instead of creating a new one" do
        stub_messages({ "id" => punishment.id, "message" => "Updated message" })

        expect { consumer.consume }.not_to change(UserPunishmentAppeal, :count)
      end

      it "updates user_message" do
        stub_messages({ "id" => punishment.id, "message" => "New appeal text" })
        consumer.consume

        expect(existing_appeal.reload.user_message).to eq("New appeal text")
      end

      it "resets status to pending" do
        stub_messages({ "id" => punishment.id, "message" => "Reconsider please" })
        consumer.consume

        expect(existing_appeal.reload.status).to eq("pending")
      end

      it "clears admin_comment" do
        stub_messages({ "id" => punishment.id, "message" => "Try again" })
        consumer.consume

        expect(existing_appeal.reload.admin_comment).to be_nil
      end

      it "sets can_reappeal to true" do
        stub_messages({ "id" => punishment.id, "message" => "One more time" })
        consumer.consume

        expect(existing_appeal.reload.can_reappeal).to be true
      end
    end

    context "when punishment does not exist" do
      it "skips the message" do
        stub_messages({ "id" => "nonexistent-id", "message" => "Hello" })

        expect { consumer.consume }.not_to change(UserPunishmentAppeal, :count)
      end
    end

    context "with nested payload structure" do
      it "extracts data from payload.payload" do
        punishment
        stub_messages({ "payload" => { "id" => punishment.id, "message" => "Nested" } })

        expect { consumer.consume }.to change(UserPunishmentAppeal, :count).by(1)
        expect(UserPunishmentAppeal.last.user_message).to eq("Nested")
      end

      it "falls back to top-level payload" do
        punishment
        stub_messages({ "id" => punishment.id, "message" => "Top level" })

        expect { consumer.consume }.to change(UserPunishmentAppeal, :count).by(1)
        expect(UserPunishmentAppeal.last.user_message).to eq("Top level")
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

      it "processes all messages" do
        punishment
        punishment2
        stub_messages(
          { "id" => punishment.id, "message" => "First" },
          { "id" => punishment2.id, "message" => "Second" }
        )

        expect { consumer.consume }.to change(UserPunishmentAppeal, :count).by(2)
      end
    end

    context "when an error occurs" do
      it "rescues and logs the error" do
        allow(UsersPunishment).to receive(:find_by).and_raise(StandardError, "DB error")
        stub_messages({ "id" => "some-id", "message" => "test" })

        expect(Rails.logger).to receive(:error).with(/Ошибка при обработке обращения/)
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

        stub_messages(
          { "id" => "bad-id", "message" => "fail" },
          { "id" => punishment.id, "message" => "succeed" }
        )

        expect { consumer.consume }.to change(UserPunishmentAppeal, :count).by(1)
      end
    end

    context "with nil id in payload" do
      it "handles gracefully" do
        stub_messages({ "id" => nil, "message" => "test" })

        expect { consumer.consume }.not_to raise_error
        expect(UserPunishmentAppeal.count).to eq(0)
      end
    end
  end
end
