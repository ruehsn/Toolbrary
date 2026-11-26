# Owners can check a tool out to someone who isn't on Tool Share (just a name).
class AllowOfflineBorrowers < ActiveRecord::Migration[8.1]
  def change
    change_column_null :borrow_requests, :borrower_id, true
    add_column :borrow_requests, :borrower_name, :string
    add_column :borrow_requests, :checked_out_at, :datetime
  end
end
