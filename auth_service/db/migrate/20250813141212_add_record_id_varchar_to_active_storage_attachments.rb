class AddRecordIdVarcharToActiveStorageAttachments < ActiveRecord::Migration[7.2]
  def change
    # Удаляем старую таблицу
    drop_table :active_storage_attachments, if_exists: true

    # Создаём заново с правильным типом record_id
    create_table :active_storage_attachments do |t|
      t.string  :name, null: false
      t.string  :record_type, null: false
      t.string  :record_id, null: false, limit: 36
      t.bigint  :blob_id, null: false
      t.datetime :created_at, null: false

      t.index :blob_id
      t.index [:record_type, :record_id, :name, :blob_id],
              unique: true,
              name: "index_active_storage_attachments_uniqueness"
    end

    add_foreign_key :active_storage_attachments,
                    :active_storage_blobs,
                    column: :blob_id
  end
end
