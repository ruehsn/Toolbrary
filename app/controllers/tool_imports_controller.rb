class ToolImportsController < ApplicationController
  before_action :set_import, only: %i[show destroy confirm]

  def new
    @tool_import = Current.user.tool_imports.new
  end

  def create
    @tool_import = Current.user.tool_imports.new
    @tool_import.photos.attach(Array(params.dig(:tool_import, :photos)).compact_blank)
    if @tool_import.save
      AnalyzeToolImportJob.perform_later(@tool_import)
      redirect_to @tool_import
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @categories = Category.alphabetical
  end

  # Creates a tool for each item the user kept, using a crop of the source photo.
  def confirm
    return redirect_to(@tool_import) unless @tool_import.ready?

    chosen = params.fetch(:items, {}).to_unsafe_h.values.select { |i| i["include"] == "1" }
    created = []
    Tool.transaction do
      chosen.each do |attrs|
        item = @tool_import.items[attrs["index"].to_i] or next
        tool = Current.user.tools.new(
          name: attrs["name"], description: attrs["description"], condition: attrs["condition"].presence,
          category_id: attrs["category_id"].presence
        )
        attach_cropped_photo(tool, item)
        tool.save!
        created << tool
      end
      @tool_import.update!(status: "completed")
    end
    redirect_to dashboard_path, notice: "Added #{helpers.pluralize(created.size, "tool")} to your shed."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @tool_import, alert: "Couldn't add “#{e.record.name.presence || "untitled"}”: #{e.record.errors.full_messages.to_sentence}"
  end

  def destroy
    @tool_import.destroy
    redirect_to dashboard_path, notice: "Photo import discarded.", status: :see_other
  end

  private
    def set_import
      @tool_import = Current.user.tool_imports.find(params[:id])
    end

    def attach_cropped_photo(tool, item)
      photo = @tool_import.item_photo(item) or return
      crop = @tool_import.crop_for(item)
      photo.blob.open do |file|
        pipeline = ImageProcessing::Vips.source(file.path)
        pipeline = pipeline.crop(*crop) if crop
        output = pipeline.resize_to_limit(1600, 1600).convert("jpg").saver(quality: 85).call
        tool.photos.attach(io: File.open(output.path), filename: "#{tool.name.parameterize.presence || "tool"}.jpg", content_type: "image/jpeg")
      end
    end
end
