class Tool < ApplicationRecord
  CATEGORIES = [
    "Power tools", "Hand tools", "Garden & yard", "Ladders & access",
    "Measuring", "Plumbing", "Electrical", "Automotive", "Cleaning", "Other"
  ].freeze
  CONDITIONS = %w[New Good Fair Worn].freeze

  belongs_to :user
  has_many :borrow_requests, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :condition, inclusion: { in: CONDITIONS }, allow_blank: true

  scope :search, ->(q) {
    q.present? ? where("tools.name LIKE :q OR tools.description LIKE :q", q: "%#{sanitize_sql_like(q)}%") : all
  }
  scope :in_category, ->(c) { c.present? ? where(category: c) : all }
  scope :available, -> { where.not(id: BorrowRequest.approved.select(:tool_id)) }

  def current_loan
    borrow_requests.approved.order(:start_date).first
  end

  def available?
    current_loan.nil?
  end

  def owned_by?(other)
    other.present? && user_id == other.id
  end
end
