class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Toolbrary <no-reply@example.com>")
  layout "mailer"
end
