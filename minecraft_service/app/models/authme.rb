class Authme < ApplicationRecord
  self.table_name = "authme"

  def self.find_username_by_realname(realname)
    find_by(realname: realname)&.username
  end
end
