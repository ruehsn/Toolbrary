class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :passkeys, dependent: :destroy
  has_many :tools, dependent: :destroy
  has_many :tool_imports, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :borrow_requests, foreign_key: :borrower_id, dependent: :destroy, inverse_of: :borrower
  has_many :incoming_requests, through: :tools, source: :borrow_requests

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true, length: { maximum: 60 }
  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }

  before_create { self.webauthn_id ||= WebAuthn.generate_user_id }

  # A magic link stops working after 15 minutes or as soon as the user signs in
  # by any means, because last_signed_in_at is part of the token.
  generates_token_for :magic_link, expires_in: 15.minutes do
    last_signed_in_at
  end

  def record_sign_in!
    update_column(:last_signed_in_at, Time.current)
  end
end
