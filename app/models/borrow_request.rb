# Lifecycle: pending -> approved -> returned
#            pending -> declined | cancelled
class BorrowRequest < ApplicationRecord
  STATUSES = %w[pending approved declined returned cancelled].freeze

  belongs_to :tool
  belongs_to :borrower, class_name: "User"

  validates :status, inclusion: { in: STATUSES }
  validates :start_date, :due_date, presence: true
  validate :due_after_start
  validate :not_own_tool, on: :create
  validate :tool_free, if: -> { status == "approved" && will_save_change_to_status? }

  STATUSES.each do |s|
    scope s, -> { where(status: s) }
    define_method("#{s}?") { status == s }
  end
  scope :open, -> { where(status: %w[pending approved]) }
  scope :recent_first, -> { order(created_at: :desc) }

  def owner = tool.user

  def overdue?
    approved? && due_date.present? && due_date < Date.current
  end

  def approve!  = update!(status: "approved")
  def decline!  = update!(status: "declined")
  def cancel!   = update!(status: "cancelled")
  def mark_returned! = update!(status: "returned", returned_at: Time.current)

  private
    def due_after_start
      return if start_date.blank? || due_date.blank?
      errors.add(:due_date, "must be on or after the start date") if due_date < start_date
    end

    def not_own_tool
      errors.add(:base, "You can't borrow your own tool") if tool && borrower_id == tool.user_id
    end

    def tool_free
      if tool.borrow_requests.approved.where.not(id: id).exists?
        errors.add(:base, "This tool is already lent out. Mark it returned first.")
      end
    end
end
