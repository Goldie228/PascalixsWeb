class FixReportAttachmentsTable < ActiveRecord::Migration[7.2]
  def change
    # Удаляем таблицу, если она существует в неправильном состоянии
    drop_table :report_attachments if table_exists?(:report_attachments)
    
    # Создаем таблицу правильно
    create_table :report_attachments, id: false do |t|
      t.string :id, null: false, primary_key: true, limit: 36
      t.references :user_report, null: false, type: :string, limit: 36, foreign_key: true
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :file_size, null: false
      t.timestamps
    end
    
    add_index :report_attachments, :id, unique: true
  end
end
