require 'rails_helper'

RSpec.describe DropedUser, type: :model do
  # --- Validations ---
  describe 'validations' do
    subject { build(:droped_user) }

    it { is_expected.to validate_presence_of(:name) }

    it 'validates uniqueness of name' do
      create(:droped_user, name: 'TestUser')
      duplicate = build(:droped_user, name: 'TestUser')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it 'validates length of name (3-27 characters)' do
      short_name = build(:droped_user, name: 'ab')
      expect(short_name).not_to be_valid
      expect(short_name.errors[:name]).to be_present

      long_name = build(:droped_user, name: 'a' * 28)
      expect(long_name).not_to be_valid
      expect(long_name.errors[:name]).to be_present

      valid_name = build(:droped_user, name: 'abc')
      expect(valid_name).to be_valid
    end

    it 'validates name format (alphanumeric and underscores only)' do
      user = build(:droped_user, name: 'valid_name_123')
      expect(user).to be_valid
    end

    it 'rejects names with special characters' do
      user = build(:droped_user, name: 'invalid-name!')
      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end

    it 'rejects names with spaces' do
      user = build(:droped_user, name: 'invalid name')
      expect(user).not_to be_valid
    end
  end

  # --- Name format edge cases ---
  describe 'name format' do
    it 'accepts names with only letters' do
      user = build(:droped_user, name: 'Player')
      expect(user).to be_valid
    end

    it 'accepts names with only numbers' do
      user = build(:droped_user, name: '12345')
      expect(user).to be_valid
    end

    it 'accepts names with underscores' do
      user = build(:droped_user, name: 'player_one')
      expect(user).to be_valid
    end

    it 'rejects names with hyphens' do
      user = build(:droped_user, name: 'player-one')
      expect(user).not_to be_valid
    end

    it 'rejects names with dots' do
      user = build(:droped_user, name: 'player.one')
      expect(user).not_to be_valid
    end
  end

  # --- Name length edge cases ---
  describe 'name length' do
    it 'rejects names shorter than 3 characters' do
      user = build(:droped_user, name: 'ab')
      expect(user).not_to be_valid
    end

    it 'accepts names of exactly 3 characters' do
      user = build(:droped_user, name: 'abc')
      expect(user).to be_valid
    end

    it 'accepts names of exactly 27 characters' do
      user = build(:droped_user, name: 'a' * 27)
      expect(user).to be_valid
    end

    it 'rejects names longer than 27 characters' do
      user = build(:droped_user, name: 'a' * 28)
      expect(user).not_to be_valid
    end
  end

  # --- Factory ---
  describe 'factory' do
    it 'has a valid factory' do
      expect(create(:droped_user)).to be_valid
    end

    it 'generates unique names via sequence' do
      user1 = create(:droped_user)
      user2 = create(:droped_user)
      expect(user1.name).not_to eq(user2.name)
    end

    it 'has a valid :custom_name trait' do
      user = create(:droped_user, :custom_name, custom_name: 'MyPlayer')
      expect(user.name).to eq('MyPlayer')
    end
  end

  # --- Primary key ---
  describe 'primary key' do
    it 'uses name as the primary key' do
      expect(DropedUser.primary_key).to eq('name')
    end
  end
end
