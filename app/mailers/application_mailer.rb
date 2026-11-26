class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Tool Share <no-reply@example.com>")
  layout "mailer"
end
