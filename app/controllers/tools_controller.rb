class ToolsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session, only: %i[index show]
  before_action :set_owned_tool, only: %i[edit update destroy check_out]

  def index
    @categories = Category.alphabetical.left_joins(:tools).group(:id).select("categories.*, COUNT(tools.id) AS tools_count")
    @category = Category.find_by(id: params[:category].to_i) if params[:category].present?
    @tools = Tool.includes(:user, :category, :borrow_requests, photos_attachments: :blob)
                 .search(params[:q])
                 .in_category(@category&.id)
                 .order(:name)
    @tools = @tools.available if params[:available] == "1"
  end

  def show
    @tool = Tool.includes(borrow_requests: :borrower).find(params[:id])
    @borrow_request = BorrowRequest.new(start_date: Date.current, due_date: Date.current + 7)
    if @tool.owned_by?(Current.user)
      @history = @tool.borrow_requests.where(status: %w[approved returned]).order(checked_out_at: :desc, created_at: :desc)
    elsif Current.user
      @my_open_request = @tool.borrow_requests.open.find_by(borrower: Current.user)
    end
  end

  def new
    @tool = Current.user.tools.new(category: Category.find_by(id: params[:category_id]))
  end

  def create
    @tool = Current.user.tools.new(tool_params)
    @tool.photos.attach(new_photos) if new_photos.any?
    if @tool.save
      redirect_to @tool, notice: "#{@tool.name} added to your shed."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @tool.assign_attributes(tool_params)
    if new_photos.any? || remove_photo_ids.any?
      # Assigning the full list keeps changes pending until save, so an invalid
      # upload doesn't get attached.
      kept = @tool.photos.reject { |p| remove_photo_ids.include?(p.id) }.map(&:blob)
      @tool.photos = kept + new_photos
    end
    if @tool.save
      redirect_to @tool, notice: "Tool updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tool.destroy
    redirect_to dashboard_path, notice: "Tool removed.", status: :see_other
  end

  # Owner hands the tool to someone right now: a member (by email) or anyone by name.
  def check_out
    attrs = params.expect(check_out: %i[borrower_email borrower_name due_date])
    loan = @tool.borrow_requests.new(status: "approved", start_date: Date.current, due_date: attrs[:due_date],
                                     borrower_name: attrs[:borrower_name].to_s.squish.presence)
    if (email = attrs[:borrower_email].to_s.strip.downcase).present?
      loan.borrower = User.find_by(email_address: email)
      return redirect_to(@tool, alert: "No Tool Share member has that email. Leave email blank and just enter their name.") unless loan.borrower
    end

    if loan.save
      redirect_to @tool, notice: "Checked out to #{loan.borrower_display_name}, due back #{l loan.due_date, format: :long}."
    else
      redirect_to @tool, alert: loan.errors.full_messages.to_sentence
    end
  end

  private
    def set_owned_tool
      @tool = Current.user.tools.find(params[:id])
    end

    def tool_params
      params.fetch(:tool, {}).permit(:name, :description, :category_id, :new_category_name, :condition, :replacement_url)
    end

    def new_photos
      @new_photos ||= Array(params.dig(:tool, :photos)).compact_blank
    end

    def remove_photo_ids
      @remove_photo_ids ||= Array(params.dig(:tool, :remove_photo_ids)).compact_blank.map(&:to_i)
    end
end
