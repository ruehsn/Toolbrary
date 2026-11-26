class Passkey < ApplicationRecord
  belongs_to :user

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true

  def display_name
    nickname.presence || "Passkey added #{created_at.to_date.to_fs(:long)}"
  end
end
