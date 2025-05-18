class AddRoleIdToUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :users, :role, null: false, foreign_key: true, default: Role.find_by(name: "User")&.id

    remove_column :users, :role
  end
end
