class FixUserReports < ActiveRecord::Migration[7.2]
  def change
    drop_table :user_reports

    create_table :user_reports, id: false do |t|
      t.string :id, null: false, primary_key: true, limit: 36

      t.references :reporter, null: false, type: :string, foreign_key: { to_table: :users }
      t.references :reported_user, null: false, type: :string, foreign_key: { to_table: :users }

      t.string :title, null: false, limit: 80
      t.text :description, null: false, limit: 5000
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :user_reports, :is_active
  end
end
