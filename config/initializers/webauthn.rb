# Passkeys only work on the exact origin they were registered for.
# Set APP_ORIGIN in production, e.g. APP_ORIGIN=https://tools.example.com
app_origin = ENV.fetch("APP_ORIGIN") do
  Rails.env.test? ? "http://www.example.com" : "http://localhost:3000"
end

Rails.application.config.x.app_origin = app_origin
Rails.application.routes.default_url_options = { host: URI(app_origin).host, port: URI(app_origin).port, protocol: URI(app_origin).scheme }

WebAuthn.configure do |config|
  config.allowed_origins = [ app_origin ]
  config.rp_id = URI(app_origin).host
  config.rp_name = "Tool Share"
end
