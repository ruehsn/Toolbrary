class CreateCategories < ActiveRecord::Migration[8.1]
  DEFAULTS = [
    [ "Power tools", "⚡" ], [ "Hand tools", "🔨" ], [ "Garden & yard", "🌱" ],
    [ "Ladders & access", "🪜" ], [ "Measuring", "📏" ], [ "Plumbing", "🚰" ],
    [ "Electrical", "🔌" ], [ "Automotive", "🚗" ], [ "Cleaning", "🧽" ],
    [ "Painting", "🖌️" ], [ "Woodworking", "🪵" ], [ "Camping & outdoor", "⛺" ], [ "Other", "📦" ]
  ].freeze

  def up
    create_table :categories do |t|
      t.string :name, null: false
      t.string :icon
      t.timestamps
    end
    add_index :categories, :name, unique: true
    add_reference :tools, :category, foreign_key: true

    now = Time.current
    names = DEFAULTS.map(&:first) | select_values("SELECT DISTINCT category FROM tools WHERE category IS NOT NULL AND category != ''")
    names.each do |name|
      icon = DEFAULTS.to_h[name]
      execute "INSERT INTO categories (name, icon, created_at, updated_at) VALUES (#{quote(name)}, #{quote(icon)}, #{quote(now)}, #{quote(now)})"
    end
    execute "UPDATE tools SET category_id = (SELECT id FROM categories WHERE categories.name = tools.category)"

    remove_index :tools, :category
    remove_column :tools, :category
  end

  def down
    add_column :tools, :category, :string
    execute "UPDATE tools SET category = (SELECT name FROM categories WHERE categories.id = tools.category_id)"
    add_index :tools, :category
    remove_reference :tools, :category, foreign_key: true
    drop_table :categories
  end
end
