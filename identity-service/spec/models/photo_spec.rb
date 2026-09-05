require 'rails_helper'

RSpec.describe Photo, type: :model do
  # --- Associations ---
  describe 'associations' do
    it { is_expected.to belong_to(:gallery) }
  end

  # --- Active Storage ---
  describe 'active storage' do
    it { is_expected.to have_one_attached(:file) }
  end

  # --- Validations ---
  describe 'validations' do
    subject { build(:photo) }

    it { is_expected.to validate_length_of(:title).is_at_most(255) }

    it 'validates presence of file' do
      photo = build(:photo)
      photo.file.detach if photo.file.attached?
      expect(photo).not_to be_valid
    end
  end

  # --- Factory ---
  describe 'factory' do
    it 'has a valid factory' do
      expect(create(:photo)).to be_valid
    end

    it 'attaches a file by default' do
      photo = create(:photo)
      expect(photo.file).to be_attached
    end

    it 'has a valid :with_custom_file trait' do
      photo = create(:photo, :with_custom_file,
        file_content: 'custom content',
        file_name: 'custom.png',
        file_type: 'image/png'
      )
      expect(photo.file).to be_attached
      expect(photo.file.content_type).to eq('image/png')
    end
  end

  # --- Title validation ---
  describe 'title validation' do
    it 'allows a photo without a title' do
      photo = build(:photo, title: nil)
      expect(photo).to be_valid
    end

    it 'rejects a title longer than 255 characters' do
      photo = build(:photo, title: 'a' * 256)
      expect(photo).not_to be_valid
    end

    it 'accepts a title of exactly 255 characters' do
      photo = build(:photo, title: 'a' * 255)
      expect(photo).to be_valid
    end
  end
end
