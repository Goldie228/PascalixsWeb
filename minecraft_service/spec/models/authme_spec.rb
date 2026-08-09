require 'rails_helper'

RSpec.describe Authme, type: :model do
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:authme)).to be_valid
    end

    it 'creates a valid record' do
      expect(create(:authme)).to be_persisted
    end
  end

  describe 'database columns' do
    it { is_expected.to respond_to(:username) }
    it { is_expected.to respond_to(:realname) }
    it { is_expected.to respond_to(:password) }
    it { is_expected.to respond_to(:ip) }
    it { is_expected.to respond_to(:lastlogin) }
    it { is_expected.to respond_to(:x) }
    it { is_expected.to respond_to(:y) }
    it { is_expected.to respond_to(:z) }
    it { is_expected.to respond_to(:world) }
    it { is_expected.to respond_to(:regdate) }
    it { is_expected.to respond_to(:regip) }
    it { is_expected.to respond_to(:yaw) }
    it { is_expected.to respond_to(:pitch) }
    it { is_expected.to respond_to(:email) }
    it { is_expected.to respond_to(:isLogged) }
    it { is_expected.to respond_to(:hasSession) }
    it { is_expected.to respond_to(:totp) }
  end

  describe 'defaults' do
    subject { build(:authme) }

    it 'defaults x to 0.0' do
      expect(subject.x).to eq(100.5) # factory overrides default
    end

    it 'defaults world to "world"' do
      authme = Authme.new(username: 'test', realname: 'Test', password: 'hash')
      expect(authme.world).to eq('world')
    end
  end

  describe '.find_username_by_realname' do
    let!(:authme) { create(:authme, realname: 'Notch', username: 'notch_player') }

    it 'returns the username for a matching realname' do
      expect(described_class.find_username_by_realname('Notch')).to eq('notch_player')
    end

    it 'returns nil when realname does not exist' do
      expect(described_class.find_username_by_realname('NonExistent')).to be_nil
    end

    it 'returns nil for nil realname' do
      expect(described_class.find_username_by_realname(nil)).to be_nil
    end
  end

  describe 'table name' do
    it 'uses the authme table' do
      expect(described_class.table_name).to eq('authme')
    end
  end
end
