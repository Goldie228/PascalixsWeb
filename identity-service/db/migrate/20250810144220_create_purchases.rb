# db/migrate/20250810120000_create_purchases.rb
class CreatePurchases < ActiveRecord::Migration[7.2]
  def change
    create_table :purchases, id: { type: :string, limit: 36 } do |t|
      # кто платит
      t.string  :purchaser_user_id, limit: 36, null: false
      # над кем выполняется действие (для подарка/разбана/размута/спонсора; для доната может быть = purchaser)
      t.string  :target_user_id,    limit: 36

      # тип покупки
      t.string  :purchase_type, null: false # enum в модели

      # деньги
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string  :currency, limit: 8, null: false, default: "BYN"

      # опционально: к какому наказанию относится (для unban/unmute)
      t.integer :punishment_id

      # статус модерации/проведения
      t.string  :status, null: false, default: "pending" # pending, approved, rejected, refunded
      t.string  :review_comment, limit: 500
      t.string  :reviewed_by_user_id, limit: 36
      t.datetime :reviewed_at

      # тех. поля: json для MySQL/SQLite, jsonb для PostgreSQL
      if postgresql?
        t.jsonb :metadata, null: false, default: {}
      else
        t.json  :metadata, null: false, default: {}
      end

      # timestamps: пусть Rails обновляет updated_at сам
      t.timestamps
    end

    add_index :purchases, :purchase_type
    add_index :purchases, :status
    add_index :purchases, :created_at
    add_index :purchases, :purchaser_user_id
    add_index :purchases, :target_user_id
    add_index :purchases, :punishment_id

    add_foreign_key :purchases, :users, column: :purchaser_user_id
    add_foreign_key :purchases, :users, column: :target_user_id
    add_foreign_key :purchases, :users_punishments, column: :punishment_id

    # CHECK-constraint только если СУБД поддерживает
    if supports_check_constraints?
      add_check_constraint :purchases, "amount >= 0", name: "amount_non_negative"
    end
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name =~ /postgres/i
  end

  def supports_check_constraints?
    # PostgreSQL, SQLite — да; MySQL 8.0+ — да; 5.7 — по факту игнор.
    name = ActiveRecord::Base.connection.adapter_name.downcase
    return true if name.include?("postgresql")
    return true if name.include?("sqlite")
    return mysql_version_supports_checks?
  end

  def mysql_version_supports_checks?
    name = ActiveRecord::Base.connection.adapter_name.downcase
    return false unless name.include?("mysql")
    # На случай разных драйверов:
    v = ActiveRecord::Base.connection.select_value("SELECT VERSION()")
    Gem::Version.new(v[/\d+\.\d+\.\d+/]) >= Gem::Version.new("8.0.16") rescue false
  end
end
