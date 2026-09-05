require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  describe 'class hierarchy' do
    it 'inherits from ActionCable::Connection::Base' do
      expect(ApplicationCable::Connection.superclass).to eq(ActionCable::Connection::Base)
    end
  end

  describe 'connection identification' do
    it 'can be instantiated as a connection class' do
      expect(ApplicationCable::Connection).to be < ActionCable::Connection::Base
    end

    it 'does not define a custom identify_by' do
      # Класс connection простой — кастомной аутентификации нет
      expect(ApplicationCable::Connection).not_to respond_to(:current_user)
    end
  end
end
