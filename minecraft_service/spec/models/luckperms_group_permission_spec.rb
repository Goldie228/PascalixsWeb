require 'rails_helper'

RSpec.describe LuckpermsGroupPermission, type: :model do
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:luckperms_group_permission)).to be_valid
    end

    it 'creates a valid record' do
      expect(create(:luckperms_group_permission)).to be_persisted
    end

    it 'supports the displayname trait' do
      perm = create(:luckperms_group_permission, :displayname)
      expect(perm.permission).to start_with('displayname.')
    end

    it 'supports the weight trait' do
      perm = create(:luckperms_group_permission, :weight)
      expect(perm.permission).to start_with('weight.')
    end

    it 'supports the dontshow trait' do
      perm = create(:luckperms_group_permission, :dontshow)
      expect(perm.permission).to eq('group.dontshow')
    end

    it 'supports the false_value trait' do
      perm = create(:luckperms_group_permission, :false_value)
      expect(perm.value).to be false
    end
  end

  describe 'database columns' do
    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:permission) }
    it { is_expected.to respond_to(:value) }
    it { is_expected.to respond_to(:server) }
    it { is_expected.to respond_to(:world) }
    it { is_expected.to respond_to(:expiry) }
    it { is_expected.to respond_to(:contexts) }
  end

  describe '.translate_and_sort_prefixes' do
    before do
      # Права группы 'admin'
      create(:luckperms_group_permission, name: 'admin', permission: 'displayname.Administrator', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')
      create(:luckperms_group_permission, name: 'admin', permission: 'weight.100', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')

      # Права группы 'vip'
      create(:luckperms_group_permission, name: 'vip', permission: 'displayname.VIP Player', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')
      create(:luckperms_group_permission, name: 'vip', permission: 'weight.50', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')

      # Права группы 'member' (без displayname, без weight)
      create(:luckperms_group_permission, name: 'member', permission: 'some.other.permission', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')

      # Права группы 'hidden' (с dontshow)
      create(:luckperms_group_permission, name: 'hidden', permission: 'group.dontshow', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')
      create(:luckperms_group_permission, name: 'hidden', permission: 'displayname.Hidden Group', value: true, server: 'global', world: 'global', expiry: 0, contexts: '{}')
    end

    it 'returns a hash sorted by weight descending' do
      prefixes = ['admin', 'vip']
      result = described_class.translate_and_sort_prefixes(prefixes)

      expect(result.keys).to eq([100, 50])
    end

    it 'extracts display names from displayname permissions' do
      prefixes = ['admin', 'vip']
      result = described_class.translate_and_sort_prefixes(prefixes)

      expect(result[100][:name]).to eq('Administrator')
      expect(result[50][:name]).to eq('VIP Player')
    end

    it 'extracts system names' do
      prefixes = ['admin', 'vip']
      result = described_class.translate_and_sort_prefixes(prefixes)

      expect(result[100][:system_name]).to eq('admin')
      expect(result[50][:system_name]).to eq('vip')
    end

    it 'uses capitalized prefix as fallback when no displayname permission exists' do
      prefixes = ['member']
      result = described_class.translate_and_sort_prefixes(prefixes)

      expect(result[0][:name]).to eq('Member')
    end

    it 'uses weight 0 as fallback when no weight permission exists' do
      prefixes = ['member']
      result = described_class.translate_and_sort_prefixes(prefixes)

      expect(result.keys).to eq([0])
    end

    it 'excludes groups with dontshow permission' do
      prefixes = ['admin', 'hidden']
      result = described_class.translate_and_sort_prefixes(prefixes)

      system_names = result.values.map { |v| v[:system_name] }
      expect(system_names).to include('admin')
      expect(system_names).not_to include('hidden')
    end

    it 'handles empty prefixes array' do
      result = described_class.translate_and_sort_prefixes([])
      expect(result).to eq({})
    end

    it 'handles prefixes with no matching permissions' do
      prefixes = ['nonexistent']
      result = described_class.translate_and_sort_prefixes(prefixes)

      expect(result[0][:system_name]).to eq('nonexistent')
      expect(result[0][:name]).to eq('Nonexistent')
    end
  end
end
