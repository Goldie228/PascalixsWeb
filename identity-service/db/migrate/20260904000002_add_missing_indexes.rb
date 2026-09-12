class AddMissingIndexes < ActiveRecord::Migration[7.2]
  def change
    # users_punishments — часто используется для поиска по пользователю
    add_index :users_punishments, :user_id, if_not_exists: true
    add_index :users_punishments, :bad_user_id, if_not_exists: true
    add_index :users_punishments, :active, if_not_exists: true
    add_index :users_punishments, :issued_at, if_not_exists: true

    # user_reports — сортировка по дате
    add_index :user_reports, :created_at, if_not_exists: true

    # purchases — сортировка по дате
    add_index :purchases, :created_at, if_not_exists: true
  end
end
