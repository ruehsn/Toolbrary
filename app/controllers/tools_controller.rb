class ToolsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session, only: %i[index show]
  before_action :set_owned_tool, only: %i[edit update destroy]

  def index
    @tools = Tool.includes(:user, :borrow_requests)
                 .search(params[:q])
                 .in_category(params[:category])
                 .order(:name)
    @tools = @tools.available if params[:available] == "1"
  end

  def show
    @tool = Tool.find(params[:id])
    @borrow_request = BorrowRequest.new(start_date: Date.current, due_date: Date.current + 7)
    if Current.user && !@tool.owned_by?(Current.user)
      @my_open_request = @tool.borrow_requests.open.find_by(borrower: Current.user)
    end
  end

  def new
    @tool = Current.user.tools.new
  end

  def create
    @tool = Current.user.tools.new(tool_params)
    if @tool.save
      redirect_to @tool, notice: "#{@tool.name} added to your shed."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @tool.update(tool_params)
      redirect_to @tool, notice: "Tool updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tool.destroy
    redirect_to dashboard_path, notice: "Tool removed.", status: :see_other
  end

  private
    def set_owned_tool
      @tool = Current.user.tools.find(params[:id])
    end

    def tool_params
      params.expect(tool: %i[name description category condition])
    end
end
