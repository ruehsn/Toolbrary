class CreateTools < ActiveRecord::Migration[8.1]
  def change
    create_table :tools do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :category
      t.string :condition

      t.timestamps
    end
    add_index :tools, :category
  end
end
