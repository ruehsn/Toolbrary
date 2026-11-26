class AnalyzeToolImportJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(tool_import)
    return unless tool_import.pending?
    tool_import.update!(status: "processing")

    analyzer = ToolPhotoAnalyzer.new(categories: Category.alphabetical.pluck(:name))
    items = tool_import.photos.each_with_index.flat_map do |photo, index|
      analyzer.analyze(photo.blob).map { |item| item.merge("photo_index" => index) }
    end

    tool_import.accept_items!(items)
  rescue ToolPhotoAnalyzer::Error => e
    tool_import.update!(status: "failed", error: e.message)
  end
end
