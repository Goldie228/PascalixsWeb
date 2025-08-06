class CreateReportAttachments < ActiveRecord::Migration[7.2]
  def change
    create_table :report_attachments, id: :uuid do |t|
      # Связь с жалобой
      t.references :user_report, null: false, type: :uuid, foreign_key: true

      # Информация о файле
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :file_size, null: false

      t.timestamps
    end
  end
end
