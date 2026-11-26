class CreateBorrowRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :borrow_requests do |t|
      t.references :tool, null: false, foreign_key: true
      t.references :borrower, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.text :message
      t.date :start_date
      t.date :due_date
      t.datetime :returned_at

      t.timestamps
    end
  end
end
