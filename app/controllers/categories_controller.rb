class CategoriesController < ApplicationController
  allow_unauthenticated_access only: :index
  before_action :resume_session, only: :index

  def index
    @categories = Category.alphabetical.left_joins(:tools).group(:id).select("categories.*, COUNT(tools.id) AS tools_count")
    @category = Category.new
  end

  def create
    @category = Category.new(params.expect(category: %i[name icon]))
    if @category.save
      redirect_to categories_path, notice: "Category “#{@category.name}” added."
    else
      @categories = Category.alphabetical.left_joins(:tools).group(:id).select("categories.*, COUNT(tools.id) AS tools_count")
      render :index, status: :unprocessable_entity
    end
  end
end
