# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebEventsProducer do
  let(:kafka_producer) { instance_double(Karafka.producer.class) }

  before do
    allow(Karafka).to receive(:producer).and_return(kafka_producer)
    allow(kafka_producer).to receive(:produce_sync)
  end

  describe '.page_viewed' do
    it 'publishes a page_viewed event to the web_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(
          topic: 'web_events',
          payload: a_string_including('page_viewed')
        )
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('page_viewed')
        expect(payload['user_id']).to eq(42)
        expect(payload['page_path']).to eq('/dashboard')
        expect(payload['referrer']).to eq('/home')
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.page_viewed(42, '/dashboard', '/home')
      expect(result).to be true
    end

    it 'allows nil user_id for anonymous users' do
      expect(kafka_producer).to receive(:produce_sync) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['user_id']).to be_nil
      end

      described_class.page_viewed(nil, '/about', nil)
    end
  end

  describe '.user_action' do
    it 'publishes a user_action event to the web_events topic' do
      details = { button: 'signup', section: 'hero' }

      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'web_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('user_action')
        expect(payload['user_id']).to eq(7)
        expect(payload['action_type']).to eq('click')
        expect(payload['details']).to eq('button' => 'signup', 'section' => 'hero')
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.user_action(7, 'click', details)
      expect(result).to be true
    end
  end

  describe '.error_occurred' do
    it 'publishes an error_occurred event to the web_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'web_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('error_occurred')
        expect(payload['user_id']).to eq(99)
        expect(payload['error_type']).to eq('TypeError')
        expect(payload['error_message']).to eq('undefined is not a function')
        expect(payload['page_path']).to eq('/settings')
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.error_occurred(99, 'TypeError', 'undefined is not a function', '/settings')
      expect(result).to be true
    end
  end

  describe '.performance_metric' do
    it 'publishes a performance_metric event to the web_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'web_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('performance_metric')
        expect(payload['user_id']).to eq(5)
        expect(payload['metric_name']).to eq('load_time')
        expect(payload['value']).to eq(1.23)
        expect(payload['page_path']).to eq('/home')
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.performance_metric(5, 'load_time', 1.23, '/home')
      expect(result).to be true
    end
  end

  describe 'error handling' do
    it 'returns false and logs error when Kafka is unavailable' do
      allow(kafka_producer).to receive(:produce_sync).and_raise(RuntimeError, 'connection refused')
      expect(Rails.logger).to receive(:error).with(/Error producing message to web_events/)

      result = described_class.page_viewed(1, '/test', nil)
      expect(result).to be false
    end
  end
end
