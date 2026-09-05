require 'rails_helper'

RSpec.describe LuckpermsPlayer, type: :model do
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:luckperms_player)).to be_valid
    end

    it 'creates a valid record' do
      expect(create(:luckperms_player)).to be_persisted
    end

    it 'supports the admin trait' do
      player = create(:luckperms_player, :admin)
      expect(player.primary_group).to eq('admin')
    end

    it 'supports the moderator trait' do
      player = create(:luckperms_player, :moderator)
      expect(player.primary_group).to eq('moderator')
    end
  end

  describe 'database columns' do
    it { is_expected.to respond_to(:uuid) }
    it { is_expected.to respond_to(:username) }
    it { is_expected.to respond_to(:primary_group) }
  end

  describe 'primary key' do
    it 'uses uuid as the primary key' do
      expect(described_class.primary_key).to eq('uuid')
    end
  end

  describe '.find_uuid_by_username' do
    let!(:player) { create(:luckperms_player, username: 'Notch', uuid: '069a79f4-44e9-4726-a5be-fca90e38aaf5') }

    it 'returns the uuid for a matching username' do
      expect(described_class.find_uuid_by_username('Notch')).to eq('069a79f4-44e9-4726-a5be-fca90e38aaf5')
    end

    it 'returns nil when username does not exist' do
      expect(described_class.find_uuid_by_username('NonExistent')).to be_nil
    end

    it 'returns nil for nil username' do
      expect(described_class.find_uuid_by_username(nil)).to be_nil
    end

    it 'is case-sensitive' do
      create(:luckperms_player, username: 'Steve', uuid: '12345678-1234-1234-1234-123456789012')
      expect(described_class.find_uuid_by_username('steve')).to be_nil
      expect(described_class.find_uuid_by_username('Steve')).to eq('12345678-1234-1234-1234-123456789012')
    end
  end
end
