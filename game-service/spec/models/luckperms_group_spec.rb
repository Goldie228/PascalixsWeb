require 'rails_helper'

RSpec.describe LuckpermsGroup, type: :model do
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:luckperms_group)).to be_valid
    end

    it 'creates a valid record' do
      expect(create(:luckperms_group)).to be_persisted
    end

    it 'supports the admin trait' do
      group = create(:luckperms_group, :admin)
      expect(group.name).to eq('admin')
      expect(group.color).to eq('#AA0000')
    end

    it 'supports the moderator trait' do
      group = create(:luckperms_group, :moderator)
      expect(group.name).to eq('moderator')
      expect(group.color).to eq('#55FF55')
    end

    it 'supports the member trait' do
      group = create(:luckperms_group, :member)
      expect(group.name).to eq('member')
      expect(group.color).to eq('#FFFFFF')
    end

    it 'supports the vip trait' do
      group = create(:luckperms_group, :vip)
      expect(group.name).to eq('vip')
      expect(group.color).to eq('#FFAA00')
    end
  end

  describe 'database columns' do
    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:color) }
  end

  describe 'defaults' do
    it 'defaults color to #FFFFFF' do
      group = LuckpermsGroup.new(name: 'test_group')
      expect(group.color).to eq('#FFFFFF')
    end
  end

  describe 'primary key' do
    it 'uses name as the primary key' do
      expect(described_class.primary_key).to eq('name')
    end
  end

  describe '.merge_colors' do
    before do
      create(:luckperms_group, name: 'admin', color: '#AA0000')
      create(:luckperms_group, name: 'vip', color: '#FFAA00')
    end

    it 'assigns colors from database to prefixes hash' do
      prefixes = {
        0 => { system_name: 'admin', name: 'Admin' },
        1 => { system_name: 'vip', name: 'VIP' }
      }

      result = described_class.merge_colors(prefixes)

      expect(result[0][:color]).to eq('#AA0000')
      expect(result[1][:color]).to eq('#FFAA00')
    end

    it 'uses default color #989898 for groups not found in database' do
      prefixes = {
        0 => { system_name: 'nonexistent', name: 'Unknown' }
      }

      result = described_class.merge_colors(prefixes)

      expect(result[0][:color]).to eq('#989898')
    end

    it 'returns the modified prefixes hash' do
      prefixes = {
        0 => { system_name: 'admin', name: 'Admin' }
      }

      result = described_class.merge_colors(prefixes)

      expect(result).to be_a(Hash)
      expect(result[0]).to have_key(:color)
    end

    it 'handles empty prefixes hash' do
      expect(described_class.merge_colors({})).to eq({})
    end
  end
end
