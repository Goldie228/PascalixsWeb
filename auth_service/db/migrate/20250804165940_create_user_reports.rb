class CreateUserReports < ActiveRecord::Migration[7.2]
  def change
    create_table :user_reports, id: :uuid do |t|
      # Кто отправил жалобу
      t.references :reporter, null: false, type: :uuid, foreign_key: { to_table: :users }

      # На кого пожаловались
      t.references :reported_user, null: false, type: :uuid, foreign_key: { to_table: :users }

      # Содержание жалобы
      t.string :title, null: false, limit: 80
      t.text :description, null: false, limit: 5000

      # Статус жалобы
      t.string :is_active, null: false, default: true

      # Временные метки
      t.timestamps
    end

    # Индексы для ускорения запросов
    add_index :user_reports, :is_active
  end
end
