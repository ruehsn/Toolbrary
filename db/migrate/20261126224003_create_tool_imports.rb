class CreateToolImports < ActiveRecord::Migration[8.1]
  def change
    create_table :tool_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.json :items, null: false, default: []
      t.text :error
      t.timestamps
    end
  end
end
