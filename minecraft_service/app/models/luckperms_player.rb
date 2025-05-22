class LuckpermsPlayer < ApplicationRecord
  def self.find_uuid_by_username(username)
    find_by(username: username)&.uuid
  end
end
