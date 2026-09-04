class AddForeignKeysToSchema < ActiveRecord::Migration[7.2]
  def change
    # users_punishments -> users (user_id)
    add_foreign_key :users_punishments, :users, column: :user_id

    # users_punishments -> users (bad_user_id)
    add_foreign_key :users_punishments, :users, column: :bad_user_id

    # user_punishment_appeals -> users_punishments
    add_foreign_key :user_punishment_appeals, :users_punishments, column: :punishment_id

    # purchases -> users (purchaser_user_id)
    add_foreign_key :purchases, :users, column: :purchaser_user_id

    # purchases -> users (target_user_id)
    add_foreign_key :purchases, :users, column: :target_user_id

    # purchases -> users_punishments
    add_foreign_key :purchases, :users_punishments, column: :punishment_id

    # user_reports -> users (reporter_id)
    add_foreign_key :user_reports, :users, column: :reporter_id

    # user_reports -> users (reported_user_id)
    add_foreign_key :user_reports, :users, column: :reported_user_id

    # discord_avatars -> discord_accounts
    add_foreign_key :discord_avatars, :discord_accounts

    # photos -> galleries
    add_foreign_key :photos, :galleries
  end
end
