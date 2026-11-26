class Tool < ApplicationRecord
  CONDITIONS = %w[New Good Fair Worn].freeze
  PHOTO_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif image/gif].freeze
  MAX_PHOTOS = 8

  belongs_to :user
  belongs_to :category, optional: true
  has_many :borrow_requests, dependent: :destroy
  has_many_attached :photos do |photo|
    photo.variant :thumb, resize_to_fill: [ 480, 360 ], format: :webp, preprocessed: true
    photo.variant :large, resize_to_limit: [ 1400, 1400 ], format: :webp
  end

  # Set from the form to create a category on the fly.
  attr_accessor :new_category_name
  before_validation :assign_new_category

  validates :name, presence: true, length: { maximum: 100 }
  validates :condition, inclusion: { in: CONDITIONS }, allow_blank: true
  validates :replacement_url, length: { maximum: 2000 },
                              format: { with: %r{\Ahttps?://\S+\z}i, message: "must start with http:// or https://" },
                              allow_blank: true
  validate :acceptable_photos

  scope :search, ->(q) {
    q.present? ? where("tools.name LIKE :q OR tools.description LIKE :q", q: "%#{sanitize_sql_like(q)}%") : all
  }
  scope :in_category, ->(id) { id.present? ? where(category_id: id.to_i) : all }
  scope :available, -> { where.not(id: BorrowRequest.approved.select(:tool_id)) }

  def current_loan
    borrow_requests.find(&:approved?)
  end

  def available?
    current_loan.nil?
  end

  def owned_by?(other)
    other.present? && user_id == other.id
  end

  # A shopping search as a fallback when the owner hasn't saved a specific link.
  def replacement_search_url
    "https://www.google.com/search?tbm=shop&q=#{ERB::Util.url_encode(name)}"
  end

  private
    def assign_new_category
      self.category = Category.find_or_create_by_name(new_category_name) if new_category_name.present?
    end

    def acceptable_photos
      errors.add(:photos, "can't be more than #{MAX_PHOTOS}") if photos.size > MAX_PHOTOS
      photos.each do |photo|
        errors.add(:photos, "must be images (JPEG, PNG, WebP or HEIC)") unless PHOTO_TYPES.include?(photo.content_type)
        errors.add(:photos, "must each be under 15 MB") if photo.byte_size > 15.megabytes
      end
    end
end
