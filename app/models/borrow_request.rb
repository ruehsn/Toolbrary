# A loan of a tool. Two ways in:
#   * a member requests it:   pending -> approved (checked out) -> returned (checked in)
#                             pending -> declined | cancelled
#   * the owner checks it out directly (member or a named non-member): approved -> returned
class BorrowRequest < ApplicationRecord
  STATUSES = %w[pending approved declined returned cancelled].freeze

  belongs_to :tool
  belongs_to :borrower, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :start_date, :due_date, presence: true
  validates :borrower_name, length: { maximum: 80 }
  validate :borrower_present
  validate :due_after_start
  validate :not_own_tool, on: :create
  validate :tool_free, if: -> { status == "approved" && will_save_change_to_status? }

  before_save { self.checked_out_at ||= Time.current if approved? }

  STATUSES.each do |s|
    scope s, -> { where(status: s) }
    define_method("#{s}?") { status == s }
  end
  scope :open, -> { where(status: %w[pending approved]) }
  scope :recent_first, -> { order(created_at: :desc) }

  def owner = tool.user
  def borrower_display_name = borrower&.name || borrower_name

  def overdue?
    approved? && due_date.present? && due_date < Date.current
  end

  def approve!  = update!(status: "approved")
  def decline!  = update!(status: "declined")
  def cancel!   = update!(status: "cancelled")
  def mark_returned! = update!(status: "returned", returned_at: Time.current)

  private
    def borrower_present
      errors.add(:base, "Say who is borrowing it") if borrower.nil? && borrower_name.blank?
    end

    def due_after_start
      return if start_date.blank? || due_date.blank?
      errors.add(:due_date, "must be on or after the start date") if due_date < start_date
    end

    def not_own_tool
      errors.add(:base, "You can't borrow your own tool") if tool && borrower_id.present? && borrower_id == tool.user_id
    end

    def tool_free
      if tool.borrow_requests.approved.where.not(id: id).exists?
        errors.add(:base, "This tool is already checked out. Check it in first.")
      end
    end
end
