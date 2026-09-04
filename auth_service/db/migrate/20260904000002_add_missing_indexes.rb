class AddMissingIndexes < ActiveRecord::Migration[7.2]
  def change
    # users_punishments — часто используется для поиска по пользователю
    add_index :users_punishments, :user_id
    add_index :users_punishments, :bad_user_id
    add_index :users_punishments, :active
    add_index :users_punishments, :issued_at

    # user_reports — сортировка по дате
    add_index :user_reports, :created_at

    # purchases — сортировка по дате
    add_index :purchases, :created_at
  end
end
