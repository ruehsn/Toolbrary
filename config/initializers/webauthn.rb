# Passkeys only work on the exact origin they were registered for (config.x.app_origin).
app_origin = Rails.application.config.x.app_origin
Rails.application.routes.default_url_options = { host: URI(app_origin).host, port: URI(app_origin).port, protocol: URI(app_origin).scheme }

WebAuthn.configure do |config|
  config.allowed_origins = [ app_origin ]
  config.rp_id = URI(app_origin).host
  config.rp_name = "Toolbrary"
end
