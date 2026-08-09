require 'rails_helper'

RSpec.describe LuckpermsUserPermission, type: :model do
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:luckperms_user_permission)).to be_valid
    end

    it 'creates a valid record' do
      expect(create(:luckperms_user_permission)).to be_persisted
    end

    it 'supports the group_permission trait' do
      perm = create(:luckperms_user_permission, :group_permission)
      expect(perm.permission).to start_with('group.')
    end

    it 'supports the false_value trait' do
      perm = create(:luckperms_user_permission, :false_value)
      expect(perm.value).to be false
    end
  end

  describe 'database columns' do
    it { is_expected.to respond_to(:uuid) }
    it { is_expected.to respond_to(:permission) }
    it { is_expected.to respond_to(:value) }
    it { is_expected.to respond_to(:server) }
    it { is_expected.to respond_to(:world) }
    it { is_expected.to respond_to(:expiry) }
    it { is_expected.to respond_to(:contexts) }
  end

  describe '.player_prefixes' do
    let(:uuid) { 'a1b2c3d4-e5f6-7890-abcd-ef0000000001' }

    before do
      create(:luckperms_user_permission, uuid: uuid, permission: 'group.admin', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')
      create(:luckperms_user_permission, uuid: uuid, permission: 'group.vip', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')
      create(:luckperms_user_permission, uuid: uuid, permission: 'group.member', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')
      # Не-групповое право (должно быть исключено)
      create(:luckperms_user_permission, uuid: uuid, permission: 'some.other.permission', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')
      # Групповое право со значением false (должно быть исключено)
      create(:luckperms_user_permission, uuid: uuid, permission: 'group.banned', value: false, server: 'global', world: 'global', expiry: 0, contexts: '{}')
      # Право другого игрока (должно быть исключено)
      create(:luckperms_user_permission, uuid: 'other-uuid-0000-0000-000000000002', permission: 'group.other', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')
    end

    it 'returns group names for the given player uuid' do
      result = described_class.player_prefixes(uuid)
      expect(result).to contain_exactly('admin', 'vip', 'member')
    end

    it 'strips the group. prefix from permissions' do
      result = described_class.player_prefixes(uuid)
      result.each do |group_name|
        expect(group_name).not_to start_with('group.')
      end
    end

    it 'only includes permissions with value true' do
      result = described_class.player_prefixes(uuid)
      expect(result).not_to include('banned')
    end

    it 'only includes group permissions' do
      result = described_class.player_prefixes(uuid)
      expect(result).not_to include('some.other.permission')
    end

    it 'only returns permissions for the specified uuid' do
      result = described_class.player_prefixes(uuid)
      expect(result).not_to include('other')
    end

    it 'returns empty array for player with no group permissions' do
      result = described_class.player_prefixes('nonexistent-uuid-0000-0000-000000000003')
      expect(result).to eq([])
    end

    it 'returns empty array for nil uuid' do
      result = described_class.player_prefixes(nil)
      expect(result).to eq([])
    end
  end
end
