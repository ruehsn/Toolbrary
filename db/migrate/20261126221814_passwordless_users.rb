class PasswordlessUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :password_digest, :string, null: false
    # Stable, random WebAuthn "user handle" so passkeys never expose the DB id.
    add_column :users, :webauthn_id, :string
    add_index :users, :webauthn_id, unique: true
    # Changes on every sign-in, which makes outstanding magic links single-use.
    add_column :users, :last_signed_in_at, :datetime
  end
end
