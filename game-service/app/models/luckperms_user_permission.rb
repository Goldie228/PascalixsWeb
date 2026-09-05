class LuckpermsUserPermission < ApplicationRecord
  def self.player_prefixes(uuid)
    where(uuid: uuid, value: true)
      .where("permission LIKE ?", "group.%")
      .pluck(:permission)
      .map { |perm| perm.gsub("group.", "") }
  end
end
