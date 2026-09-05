require 'rails_helper'

RSpec.describe Gallery, type: :model do
  # --- Associations ---
  describe 'associations' do
    it { is_expected.to have_many(:photos).dependent(:destroy) }
  end

  # --- Validations ---
  describe 'validations' do
    subject { build(:gallery) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(4096) }
  end

  # --- Custom validation: cannot_be_published_without_photos ---
  describe '#cannot_be_published_without_photos' do
    context 'when gallery is published and has no photos' do
      it 'is invalid' do
        gallery = build(:gallery, published: true)
        expect(gallery).not_to be_valid
        expect(gallery.errors[:published]).to include('cannot be published without photos')
      end
    end

    context 'when gallery is published and has photos' do
      it 'is valid' do
        gallery = create(:gallery, :published)
        expect(gallery).to be_valid
      end
    end

    context 'when gallery is not published and has no photos' do
      it 'is valid' do
        gallery = build(:gallery, published: false)
        expect(gallery).to be_valid
      end
    end
  end

  # --- Nested attributes ---
  describe 'nested attributes' do
    it 'accepts nested attributes for photos' do
      expect(Gallery.nested_attributes_options).to have_key(:photos)
    end
  end

  # --- Factory ---
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:gallery)).to be_valid
    end

    it 'has a valid :published trait' do
      gallery = create(:gallery, :published)
      expect(gallery).to be_valid
      expect(gallery.published?).to be true
      expect(gallery.photos).not_to be_empty
    end

    it 'has a valid :with_photos trait' do
      gallery = create(:gallery, :with_photos, photos_count: 5)
      expect(gallery.photos.count).to eq(5)
    end
  end

  # --- Dependent destroy ---
  describe 'dependent destroy' do
    it 'destroys associated photos when gallery is destroyed' do
      gallery = create(:gallery, :with_photos, photos_count: 3)
      photo_ids = gallery.photos.pluck(:id)

      expect { gallery.destroy }.to change(Photo, :count).by(-3)
      photo_ids.each do |id|
        expect(Photo.exists?(id)).to be false
      end
    end
  end
end
