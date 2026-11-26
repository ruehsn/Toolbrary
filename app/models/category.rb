class Category < ApplicationRecord
  DEFAULTS = {
    "Power tools" => "⚡", "Hand tools" => "🔨", "Garden & yard" => "🌱", "Ladders & access" => "🪜",
    "Measuring" => "📏", "Plumbing" => "🚰", "Electrical" => "🔌", "Automotive" => "🚗",
    "Cleaning" => "🧽", "Painting" => "🖌️", "Woodworking" => "🪵", "Camping & outdoor" => "⛺", "Other" => "📦"
  }.freeze
  has_many :tools, dependent: :nullify

  normalizes :name, with: ->(n) { n.squish }
  validates :name, presence: true, length: { maximum: 40 }, uniqueness: { case_sensitive: false }
  validates :icon, length: { maximum: 8 }

  scope :alphabetical, -> { order(Arel.sql("CASE WHEN categories.name = 'Other' THEN 1 ELSE 0 END, categories.name")) }

  def self.find_or_create_by_name(name)
    name = name.to_s.squish
    return if name.blank?
    where("LOWER(name) = ?", name.downcase).first || create(name: name, icon: "🧰")
  end

  def self.create_defaults!
    DEFAULTS.each do |name, icon|
      category = find_or_create_by_name(name)
      category.update!(icon: icon) if category.icon.blank? || category.icon == "🧰"
    end
  end

  def label = [ icon, name ].compact_blank.join(" ")

  def to_param = "#{id}-#{name.parameterize}"
end
