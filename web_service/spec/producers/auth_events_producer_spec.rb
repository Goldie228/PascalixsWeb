# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthEventsProducer do
  let(:kafka_producer) { instance_double(Karafka.producer.class) }

  before do
    allow(Karafka).to receive(:producer).and_return(kafka_producer)
    allow(kafka_producer).to receive(:produce_sync)
  end

  describe '.login_attempt' do
    it 'publishes a login_attempt event to the auth_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'auth_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('login_attempt')
        expect(payload['email']).to eq('user@example.com')
        expect(payload['success']).to be true
        expect(payload['ip_address']).to eq('192.168.1.1')
        expect(payload['user_agent']).to eq('Mozilla/5.0')
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.login_attempt('user@example.com', true, '192.168.1.1', 'Mozilla/5.0')
      expect(result).to be true
    end

    it 'allows optional ip_address and user_agent to be nil' do
      expect(kafka_producer).to receive(:produce_sync) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['ip_address']).to be_nil
        expect(payload['user_agent']).to be_nil
      end

      described_class.login_attempt('user@example.com', false)
    end

    it 'returns false when email is blank' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.login_attempt(nil, true)).to be false
    end

    it 'returns false when email is empty string' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.login_attempt('', true)).to be false
    end
  end

  describe '.logout_attempt' do
    it 'publishes a logout_attempt event to the auth_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'auth_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('logout_attempt')
        expect(payload['user_id']).to eq(42)
        expect(payload['success']).to be true
        expect(payload['ip_address']).to eq('10.0.0.1')
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.logout_attempt(42, true, '10.0.0.1')
      expect(result).to be true
    end

    it 'allows optional ip_address to be nil' do
      expect(kafka_producer).to receive(:produce_sync) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['ip_address']).to be_nil
      end

      described_class.logout_attempt(42, false)
    end

    it 'returns false when user_id is blank' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.logout_attempt(nil, true)).to be false
    end
  end

  describe '.oauth_attempt' do
    it 'publishes an oauth_attempt event to the auth_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'auth_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('oauth_attempt')
        expect(payload['provider']).to eq('discord')
        expect(payload['user_id']).to eq(55)
        expect(payload['success']).to be true
        expect(payload['error']).to be_nil
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.oauth_attempt('discord', 55, true)
      expect(result).to be true
    end

    it 'publishes with error when oauth fails' do
      expect(kafka_producer).to receive(:produce_sync) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['success']).to be false
        expect(payload['error']).to eq('invalid_token')
      end

      described_class.oauth_attempt('google', nil, false, 'invalid_token')
    end

    it 'uses default values for optional parameters' do
      expect(kafka_producer).to receive(:produce_sync) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['user_id']).to be_nil
        expect(payload['success']).to be true
        expect(payload['error']).to be_nil
      end

      described_class.oauth_attempt('github')
    end

    it 'returns false when provider is blank' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.oauth_attempt(nil)).to be false
    end

    it 'returns false when provider is empty string' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.oauth_attempt('')).to be false
    end
  end

  describe '.password_change' do
    it 'publishes a password_change event to the auth_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'auth_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('password_change')
        expect(payload['user_id']).to eq(77)
        expect(payload['success']).to be true
        expect(payload['forced']).to be false
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.password_change(77, true)
      expect(result).to be true
    end

    it 'publishes with forced=true for password reset' do
      expect(kafka_producer).to receive(:produce_sync) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['forced']).to be true
      end

      described_class.password_change(77, true, true)
    end

    it 'returns false when user_id is blank' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.password_change(nil, true)).to be false
    end

    it 'returns false when user_id is empty string' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.password_change('', true)).to be false
    end
  end

  describe 'error handling' do
    it 'returns false and logs error when Kafka is unavailable' do
      allow(kafka_producer).to receive(:produce_sync).and_raise(RuntimeError, 'connection refused')
      expect(Rails.logger).to receive(:error).with(/Error producing message to auth_events/)

      result = described_class.login_attempt('user@example.com', true)
      expect(result).to be false
    end
  end
end
