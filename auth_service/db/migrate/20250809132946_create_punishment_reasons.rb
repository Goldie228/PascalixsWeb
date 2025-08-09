class CreatePunishmentReasons < ActiveRecord::Migration[7.2]
  def change
    create_table :punishment_reasons do |t|
      t.string  :punishment_type, null: false
      t.text    :description,     null: false
      t.integer :rule_number,     null: false
      t.decimal :price, precision: 10, scale: 2, null: false, default: 1.0

      t.timestamps
    end

    add_index :punishment_reasons, [:punishment_type, :rule_number], unique: true, name: "idx_reason_type_rule_unique"
    add_index :punishment_reasons, :rule_number
  end
end
