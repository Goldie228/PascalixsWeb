class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Если нам нужно использовать UUID как в монолите
  def assign_uuid
    self.id ||= SecureRandom.uuid
  end

  def t(key, options = {})
    I18n.t(key, **options)
  end

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end
end
