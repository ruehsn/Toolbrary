# A batch of photos the user uploads so AI can find each tool in them and
# draft a listing (name, category, condition, description and a crop box).
# Lifecycle:
#   built-in AI:          pending -> processing -> ready -> completed (or -> failed)
#   user's own assistant: awaiting_assistant -> ready -> completed
#     (the assistant reads the photos and submits items over MCP; see app/mcp)
class ToolImport < ApplicationRecord
  STATUSES = %w[awaiting_assistant pending processing ready completed failed].freeze
  MAX_PHOTOS = 10

  belongs_to :user
  has_many_attached :photos

  validates :status, inclusion: { in: STATUSES }
  validate :acceptable_photos, on: :create

  STATUSES.each { |s| define_method("#{s}?") { status == s } }

  def working? = pending? || processing?

  scope :awaiting_assistant, -> { where(status: "awaiting_assistant") }

  # Validates and stores items proposed by an AI (built-in or the user's assistant).
  # Each item: name, category, condition, description, box [x0,y0,x1,y1] on 0..1000, photo_index.
  def accept_items!(raw_items)
    items = Array(raw_items).filter_map do |raw|
      raw = raw.to_h.stringify_keys
      index = Integer(raw["photo_index"] || 0, exception: false)
      next if raw["name"].blank? || index.nil? || index.negative? || index >= photos.size
      box = Array(raw["box"]).map { |v| Integer(v, exception: false) || Float(v, exception: false) }
      {
        "photo_index" => index,
        "name" => raw["name"].to_s.squish.first(100),
        "category" => raw["category"].to_s.squish.first(40),
        "condition" => Tool::CONDITIONS.find { |c| c.casecmp?(raw["condition"].to_s) },
        "description" => raw["description"].to_s.strip.first(1000),
        "box" => (box.size == 4 && box.none?(&:nil?) ? box : nil)
      }
    end
    update!(status: "ready", items: items, error: nil)
    items
  end

  # items: [{ "photo_index"=>0, "name"=>..., "category"=>..., "condition"=>...,
  #           "description"=>..., "box"=>[x_min, y_min, x_max, y_max] (0..1000) }]
  def item_photo(item) = photos[item["photo_index"].to_i]

  # Pixel crop [left, top, width, height] for an item, padded a little because
  # model boxes are approximate. Nil if we can't work it out (no box / no size).
  def crop_for(item, padding: 0.06)
    photo = item_photo(item)
    box = item["box"]
    return unless photo && box.is_a?(Array) && box.size == 4
    photo.analyze unless photo.analyzed?
    width, height = photo.metadata.values_at("width", "height")
    return unless width && height

    x0, y0, x1, y1 = box.map { |v| v.to_f.clamp(0, 1000) / 1000.0 }
    x0, x1 = [ x0, x1 ].minmax
    y0, y1 = [ y0, y1 ].minmax
    pad_x = (x1 - x0) * padding
    pad_y = (y1 - y0) * padding
    left = ((x0 - pad_x).clamp(0, 1) * width).floor
    top = ((y0 - pad_y).clamp(0, 1) * height).floor
    right = ((x1 + pad_x).clamp(0, 1) * width).ceil
    bottom = ((y1 + pad_y).clamp(0, 1) * height).ceil
    return if right - left < 16 || bottom - top < 16
    [ left, top, right - left, bottom - top ]
  end

  # Thumbnail of just this item, for the review screen.
  def item_preview(item)
    photo = item_photo(item) or return
    crop = crop_for(item)
    crop ? photo.variant(crop: crop, resize_to_limit: [ 400, 400 ], format: :webp) : photo.variant(resize_to_limit: [ 400, 400 ], format: :webp)
  end

  private
    def acceptable_photos
      errors.add(:photos, "— choose at least one photo") if photos.empty?
      errors.add(:photos, "— up to #{MAX_PHOTOS} at a time") if photos.size > MAX_PHOTOS
      photos.each do |photo|
        errors.add(:photos, "must be images (JPEG, PNG, WebP or HEIC)") unless Tool::PHOTO_TYPES.include?(photo.content_type)
        errors.add(:photos, "must each be under 15 MB") if photo.byte_size > 15.megabytes
      end
    end
end
