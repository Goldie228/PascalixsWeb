class LuckpermsGroup < ApplicationRecord
  def self.merge_colors(prefixes_hash)
    system_names = prefixes_hash.values.map { |group_info| group_info[:system_name] }

    groups_colors = where(name: system_names).pluck(:name, :color).to_h

    prefixes_hash.each do |index, group_info|
      lookup_name = group_info[:system_name]
      group_info[:color] = groups_colors[lookup_name] || "#989898"
    end

    prefixes_hash
  end
end
