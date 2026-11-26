require "base64"

# Sends a photo to Claude and gets back every tool visible in it, with a
# suggested listing and a bounding box, as schema-validated JSON.
#
# Needs ANTHROPIC_API_KEY. Swap the implementation in tests via
# ToolPhotoAnalyzer.client_factory or ToolPhotoAnalyzer.stub.
class ToolPhotoAnalyzer
  class Error < StandardError; end
  class NotConfigured < Error; end

  MODEL = :"claude-opus-5-5"
  MAX_EDGE = 1568 # px; larger images are downscaled by the API anyway

  ITEM_SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[name category condition description box],
    properties: {
      name: { type: "string", description: "Short listing title with brand/size/power if visible, e.g. 'DeWalt 18V cordless drill'" },
      category: { type: "string", description: "One of the provided category names" },
      condition: { type: "string", enum: Tool::CONDITIONS },
      description: { type: "string", description: "1-2 sentences for a borrower: what it is, notable accessories, anything to know" },
      box: {
        type: "array", items: { type: "integer" },
        description: "Bounding box [x_min, y_min, x_max, y_max] on a 0-1000 scale relative to image width/height"
      }
    }
  }.freeze

  SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[tools],
    properties: { tools: { type: "array", items: ITEM_SCHEMA } }
  }.freeze

  class << self
    attr_writer :client_factory
    # Test hook: a callable (io, categories) -> array of item hashes.
    attr_accessor :stub

    def configured? = stub.present? || ENV["ANTHROPIC_API_KEY"].present?

    def client
      @client_factory ? @client_factory.call : Anthropic::Client.new
    end
  end

  def initialize(categories:)
    @categories = categories
  end

  # blob: an ActiveStorage::Blob. Returns an array of hashes with string keys.
  def analyze(blob)
    return self.class.stub.call(blob, @categories) if self.class.stub
    raise NotConfigured, "Set ANTHROPIC_API_KEY to use AI photo import." unless self.class.configured?

    image_data = blob.open { |file| prepare_image(file.path) }
    response = self.class.client.beta.messages.create(
      model: MODEL,
      max_tokens: 16_000,
      output_config: { effort: :medium, format: { type: :json_schema, schema: SCHEMA } },
      # If the model declines for policy reasons, let the API retry on its default fallback.
      fallbacks: :default,
      betas: [ "server-side-fallback-2026-07-01" ],
      system_: system_prompt,
      messages: [ {
        role: "user",
        content: [
          { type: "image", source: { type: "base64", media_type: "image/jpeg", data: image_data } },
          { type: "text", text: "List every separate tool in this photo." }
        ]
      } ]
    )

    case response.stop_reason
    when :refusal then raise Error, "The AI declined to analyse this photo."
    when :max_tokens then raise Error, "The photo had too many items to list in one go. Try a photo with fewer tools."
    end

    text = response.content.select { |b| b.type == :text }.map(&:text).join
    JSON.parse(text).fetch("tools").map { |item| item.transform_keys(&:to_s) }
  rescue JSON::ParserError, KeyError => e
    raise Error, "Couldn't read the AI response (#{e.class})."
  rescue Anthropic::Errors::RateLimitError
    raise Error, "The AI service is busy. Please try again in a minute."
  rescue Anthropic::Errors::AuthenticationError
    raise NotConfigured, "ANTHROPIC_API_KEY was rejected."
  rescue Anthropic::Errors::APIStatusError, Anthropic::Errors::APIConnectionError => e
    raise Error, "The AI service failed (#{e.class.name.demodulize})."
  end

  private
    # Auto-rotate (EXIF), shrink and re-encode as JPEG. Auto-rotation matters:
    # boxes come back relative to the upright image, which is also what we crop.
    def prepare_image(path)
      jpeg = ImageProcessing::Vips.source(path).resize_to_limit(MAX_EDGE, MAX_EDGE).convert("jpg").saver(quality: 85).call
      Base64.strict_encode64(File.binread(jpeg.path))
    ensure
      jpeg&.close!
    end

    def system_prompt
      <<~PROMPT
        You help people catalogue their tools so neighbours can borrow them. You'll get one photo
        that may show several tools (on a bench, a pegboard, the floor, in a shed).

        Return one entry per distinct, lendable tool. Treat a matched set in one case (a socket set,
        a drill-bit set) as one entry. Skip things that aren't tools for lending: consumables
        (screws, tape, sandpaper), packaging, furniture, the workbench or pegboard itself, people.
        If no tools are visible, return an empty list.

        For each tool:
        - name: what a borrower would search for, plus brand/model/voltage/size when clearly legible.
          Don't guess brands you can't read.
        - category: pick the closest of: #{@categories.join(", ")}. Use "Other" if nothing fits.
        - condition: New, Good, Fair or Worn, judged from visible wear.
        - description: one or two plain sentences: what it's for, visible accessories (batteries,
          case, blades), anything a borrower should know.
        - box: a tight bounding box around just that tool as [x_min, y_min, x_max, y_max], integers
          on a 0-1000 scale where (0,0) is the top-left of the image and (1000,1000) the bottom-right.
      PROMPT
    end
end
