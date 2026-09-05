# Schema for nulldb adapter — web-portal has no real database.
# Columns are defined here so ActiveRecord models can build in-memory objects.
ActiveRecord::Schema[7.2].define(version: 0) do
  create_table :users, id: false, force: false do |t|
    t.string :id, primary_key: true
    t.string :email
    t.string :username
    t.timestamps
  end

  create_table :minecraft_accounts, id: false, force: false do |t|
    t.string :id, primary_key: true
    t.string :user_id
    t.string :minecraft_uuid
    t.string :username
    t.timestamps
  end
end
