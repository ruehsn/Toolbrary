# Personal access token for AI assistants connecting over MCP.
# Only a SHA-256 digest is stored; the plain token is shown once at creation.
class ApiToken < ApplicationRecord
  PREFIX = "tsk_"

  belongs_to :user

  validates :name, presence: true, length: { maximum: 60 }
  validates :token_digest, presence: true, uniqueness: true

  attr_reader :plain_token

  before_validation :generate_token, on: :create

  def self.authenticate(plain)
    return if plain.blank? || !plain.start_with?(PREFIX)
    find_by(token_digest: digest(plain))&.tap(&:touch_last_used)
  end

  def self.digest(plain) = OpenSSL::Digest::SHA256.hexdigest(plain)

  def touch_last_used
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end

  private
    def generate_token
      @plain_token = PREFIX + SecureRandom.base58(40)
      self.token_digest = self.class.digest(@plain_token)
      self.token_hint = @plain_token.last(4)
    end
end
