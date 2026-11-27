namespace :auth do
  desc "Print a one-time sign-in link (creates the user if needed). Usage: bin/rails 'auth:sign_in_link[you@example.com,Your Name]'"
  task :sign_in_link, %i[email name] => :environment do |_, args|
    abort "Usage: bin/rails 'auth:sign_in_link[you@example.com,Your Name]'" if args[:email].blank?
    user = User.find_or_create_by!(email_address: args[:email].strip.downcase) { |u| u.name = args[:name].presence || args[:email].split("@").first }
    puts "Sign-in link for #{user.email_address} (works once, expires in 15 minutes):"
    puts Rails.application.routes.url_helpers.magic_link_url(token: user.generate_token_for(:magic_link))
  end
end
