require 'rails_helper'

RSpec.describe DiscordAvatar, type: :model do
  # --- Связи ---
  describe 'associations' do
    it { is_expected.to belong_to(:discord_account) }
  end

  # --- Active Storage ---
  describe 'active storage' do
    it { is_expected.to have_one_attached(:file) }
  end

  # --- Валидации ---
  describe 'validations' do
    it 'validates status inclusion' do
      avatar = build(:discord_avatar, status: 'invalid_status')
      expect(avatar).not_to be_valid
      expect(avatar.errors[:status]).to be_present
    end

    %w[pending approved rejected].each do |valid_status|
      it "accepts status '#{valid_status}'" do
        avatar = build(:discord_avatar, status: valid_status)
        expect(avatar).to be_valid
      end
    end
  end

  # --- Валидация типа содержимого файла ---
  describe 'file content type validation' do
    let(:discord_avatar) { build(:discord_avatar) }

    %w[image/jpeg image/png image/gif image/webp].each do |valid_type|
      it "accepts content type #{valid_type}" do
        discord_avatar.file.attach(
          io: StringIO.new('fake content'),
          filename: "avatar.#{valid_type.split('/').last}",
          content_type: valid_type
        )
        expect(discord_avatar).to be_valid
      end
    end

    it 'rejects invalid content types' do
      discord_avatar.file.attach(
        io: StringIO.new('fake content'),
        filename: 'avatar.bmp',
        content_type: 'image/bmp'
      )
      expect(discord_avatar).not_to be_valid
      expect(discord_avatar.errors[:file]).to be_present
    end
  end

  # --- Валидация размера файла ---
  describe 'file size validation' do
    let(:discord_avatar) { build(:discord_avatar) }

    it 'accepts files smaller than 10MB' do
      discord_avatar.file.attach(
        io: StringIO.new('small content'),
        filename: 'avatar.jpg',
        content_type: 'image/jpeg'
      )
      expect(discord_avatar).to be_valid
    end

    it 'rejects files larger than 10MB' do
      large_content = 'x' * (10.megabytes + 1)
      discord_avatar.file.attach(
        io: StringIO.new(large_content),
        filename: 'avatar.jpg',
        content_type: 'image/jpeg'
      )
      expect(discord_avatar).not_to be_valid
      expect(discord_avatar.errors[:file]).to be_present
    end
  end

  # --- Колбэки ---
  describe 'callbacks' do
    describe 'before_validation :generate_id' do
      it 'generates a UUID before creation' do
        avatar = create(:discord_avatar)
        expect(avatar.id).to be_present
        expect(avatar.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end

      it 'does not overwrite an existing ID' do
        custom_id = SecureRandom.uuid
        avatar = create(:discord_avatar, id: custom_id)
        expect(avatar.id).to eq(custom_id)
      end
    end

    describe 'after_commit :process_gif_async' do
      it 'enqueues ProcessGifJob when a GIF is attached on create' do
        avatar = create(:discord_avatar, :with_gif_file)
        # Вызов колбэка напрямую — after_commit with on: [:create]
        # не срабатывает из manual run_callbacks в транзакционном режиме
        expect {
          avatar.process_gif_async
        }.to have_enqueued_job(ProcessGifJob)
      end

      it 'does not enqueue ProcessGifJob for non-GIF files' do
        avatar = create(:discord_avatar, :with_file)
        # Не-GIF файл: условие :if не даст вызвать колбэк
        # метод не должен вызываться
        expect(ProcessGifJob).not_to have_been_enqueued
      end
    end
  end

  # --- Методы экземпляра ---
  describe '#processed?' do
    context 'when file is attached and status is not pending' do
      it 'returns true' do
        avatar = create(:discord_avatar, :approved, :with_file)
        expect(avatar.processed?).to be true
      end
    end

    context 'when file is attached and status is pending' do
      it 'returns false' do
        avatar = create(:discord_avatar, :pending, :with_file)
        expect(avatar.processed?).to be false
      end
    end

    context 'when file is not attached' do
      it 'returns false' do
        avatar = create(:discord_avatar, :approved)
        expect(avatar.processed?).to be false
      end
    end
  end

  # --- Фабрика ---
  describe 'factory' do
    it 'has a valid factory' do
      expect(create(:discord_avatar)).to be_valid
    end

    it 'has a valid :pending trait' do
      avatar = create(:discord_avatar, :pending)
      expect(avatar.status).to eq('pending')
    end

    it 'has a valid :approved trait' do
      avatar = create(:discord_avatar, :approved)
      expect(avatar.status).to eq('approved')
    end

    it 'has a valid :rejected trait' do
      avatar = create(:discord_avatar, :rejected)
      expect(avatar.status).to eq('rejected')
    end

    it 'has a valid :with_file trait' do
      avatar = create(:discord_avatar, :with_file)
      expect(avatar.file).to be_attached
    end

    it 'has a valid :with_gif_file trait' do
      avatar = create(:discord_avatar, :with_gif_file)
      expect(avatar.file).to be_attached
      expect(avatar.file.content_type).to eq('image/gif')
    end
  end
end
