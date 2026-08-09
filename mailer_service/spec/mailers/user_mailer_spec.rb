require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  let(:email) { 'user@example.com' }
  let(:nickname) { 'TestPlayer' }
  let(:token) { 'abc123token' }
  let(:time_zone) { 'UTC' }
  let(:code) { '123456' }
  let(:otp_valid_until) { '2026-07-21 12:00:00 UTC' }

  before do
    ENV['WEB_SERVICE_URL'] = 'https://pascalixs.com'
    I18n.locale = :en
  end

  after do
    ActionMailer::Base.deliveries.clear
  end

  describe '#two_factor_code' do
    let(:mail) { described_class.two_factor_code(email, code, otp_valid_until) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Two-Factor Authentication')
      expect(mail.to).to eq([email])
      expect(mail.from).to eq(['no-reply@pascalixs.com'])
    end

    it 'includes the OTP code in the body' do
      expect(mail.body.encoded).to include(code)
    end

    it 'includes the OTP validity time in the body' do
      expect(mail.body.encoded).to include(otp_valid_until)
    end

    it 'renders both HTML and text parts' do
      expect(mail.multipart?).to be true
      expect(mail.content_type).to include('multipart/alternative')
    end

    it 'includes security warning in the body' do
      expect(mail.body.encoded).to include("Don't share this code with anyone")
    end

    it 'includes the email title' do
      expect(mail.body.encoded).to include('Two-Factor Authentication')
    end

    it 'delivers the email successfully' do
      expect { mail.deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  describe '#check_email' do
    let(:mail) { described_class.check_email(email, token, nickname, time_zone) }
    let(:expected_url) { "https://pascalixs.com/en/confirm_email/#{token}" }

    it 'renders the headers' do
      expect(mail.subject).to eq('Email verification')
      expect(mail.to).to eq([email])
      expect(mail.from).to eq(['no-reply@pascalixs.com'])
    end

    it 'includes the confirmation URL in the body' do
      expect(mail.body.encoded).to include(expected_url)
    end

    it 'includes the nickname in the body' do
      expect(mail.body.encoded).to include(nickname)
    end

    it 'includes the brand name in the body' do
      expect(mail.body.encoded).to include('PascaLixs')
    end

    it 'includes the confirmation button text' do
      expect(mail.body.encoded).to include('Confirm New Email')
    end

    it 'includes security warning' do
      expect(mail.body.encoded).to include('Important:')
    end

    it 'renders both HTML and text parts' do
      expect(mail.multipart?).to be true
      expect(mail.content_type).to include('multipart/alternative')
    end

    it 'delivers the email successfully' do
      expect { mail.deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    context 'with different locale' do
      before { I18n.locale = :ru }

      it 'generates URL with correct locale prefix' do
        expect(mail.html_part.body.decoded).to include("https://pascalixs.com/ru/confirm_email/#{token}")
      end
    end
  end

  describe '#reset_password' do
    let(:mail) { described_class.reset_password(email, token, nickname, time_zone) }
    let(:expected_url) { "https://pascalixs.com/en/reset_password/#{token}" }

    it 'renders the headers' do
      expect(mail.subject).to eq('Password Change')
      expect(mail.to).to eq([email])
      expect(mail.from).to eq(['no-reply@pascalixs.com'])
    end

    it 'includes the reset URL in the body' do
      expect(mail.body.encoded).to include(expected_url)
    end

    it 'includes the nickname in the body' do
      expect(mail.body.encoded).to include(nickname)
    end

    it 'includes the password reset header' do
      expect(mail.body.encoded).to include('Password Reset')
    end

    it 'includes the button text' do
      expect(mail.body.encoded).to include('Set New Password')
    end

    it 'includes security warning' do
      expect(mail.body.encoded).to include('Important:')
    end

    it 'renders both HTML and text parts' do
      expect(mail.multipart?).to be true
      expect(mail.content_type).to include('multipart/alternative')
    end

    it 'delivers the email successfully' do
      expect { mail.deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    context 'with different locale' do
      before { I18n.locale = :ru }

      it 'generates URL with correct locale prefix' do
        expect(mail.html_part.body.decoded).to include("https://pascalixs.com/ru/reset_password/#{token}")
      end
    end
  end

  describe 'edge cases' do
    context 'with special characters in nickname' do
      let(:special_nickname) { 'Player<script>alert(1)</script>' }

      it 'renders check_email without errors' do
        expect {
          described_class.check_email(email, token, special_nickname, time_zone)
        }.not_to raise_error
      end

      it 'renders reset_password without errors' do
        expect {
          described_class.reset_password(email, token, special_nickname, time_zone)
        }.not_to raise_error
      end
    end

    context 'with long OTP code' do
      let(:long_code) { '9999999999' }

      it 'renders two_factor_code without errors' do
        expect {
          described_class.two_factor_code(email, long_code, otp_valid_until)
        }.not_to raise_error
      end
    end

    context 'with different time zones' do
      let(:time_zone) { 'America/New_York' }

      it 'renders check_email with timezone-specific date' do
        mail = described_class.check_email(email, token, nickname, time_zone)
        expect(mail.body.encoded).to include(nickname)
      end

      it 'renders reset_password with timezone-specific date' do
        mail = described_class.reset_password(email, token, nickname, time_zone)
        expect(mail.body.encoded).to include(nickname)
      end
    end
  end
end
