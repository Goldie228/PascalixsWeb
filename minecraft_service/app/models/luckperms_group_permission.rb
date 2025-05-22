class LuckpermsGroupPermission < ApplicationRecord
  def self.translate_and_sort_prefixes(prefixes)
    names = {}
    weights = {}

    records = where(name: prefixes, value: true)
              .where("permission LIKE ? OR permission LIKE ?", "displayname.%", "weight.%")
              .or(where(name: prefixes, value: true)
              .where("permission LIKE ?", "group.dontshow%"))

    grouped_records = records.group_by(&:name)

    prefixes.each do |prefix|
      recs = grouped_records[prefix] || []

      next if recs.any? { |record| record.permission.start_with?("group.dontshow") }

      display_record  = recs.find { |record| record.permission.start_with?("displayname.") }
      weight_record   = recs.find { |record| record.permission.start_with?("weight.") }

      names[prefix]   = display_record.present? ? display_record.permission.gsub("displayname.", "") : prefix.capitalize
      weights[prefix] = weight_record.present? ? weight_record.permission.gsub("weight.", "").to_i : 0
    end

    sorted_prefixes = weights.sort_by { |_, weight| -weight }

    result = {}
    sorted_prefixes.each_with_index do |(prefix, _), index|
      result[index] = { system_name: prefix, name: names[prefix] }
    end

    result
  end
end
