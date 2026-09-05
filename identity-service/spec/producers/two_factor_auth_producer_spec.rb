require "rails_helper"

RSpec.describe TwoFactorAuthProducer do
  describe "class definition" do
    it "is defined" do
      expect(described_class).to be_a(Class)
    end

    it "inherits from Object" do
      expect(described_class.superclass).to eq(Object)
    end
  end

  describe "interface" do
    it "has no custom public class methods (producer is not yet implemented)" do
      # TwoFactorAuthProducer — пустой класс.
      # Фильтруем методы из Object/ActiveSupport — ищем только кастомные.
      base_methods = Object.public_methods
      custom_methods = described_class.public_methods - base_methods

      expect(custom_methods).to be_empty,
        "Expected TwoFactorAuthProducer to have no custom class methods, but found: #{custom_methods}"
    end
  end
end
