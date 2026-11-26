# Passkeys only work on the exact origin they were registered for.
# Set APP_ORIGIN in production, e.g. APP_ORIGIN=https://tools.example.com
app_origin = ENV.fetch("APP_ORIGIN") do
  Rails.env.test? ? "http://www.example.com" : "http://localhost:3000"
end

WebAuthn.configure do |config|
  config.allowed_origins = [ app_origin ]
  config.rp_id = URI(app_origin).host
  config.rp_name = "Tool Share"
end
