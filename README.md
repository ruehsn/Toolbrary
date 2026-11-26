# Tool Share

A small Rails 8 app for keeping track of your tools and letting other people see
what you have so they can ask to borrow it.

## Features
- **Passwordless accounts** – no passwords at all:
  - **Magic links**: enter your email and click the link we send. Sign-up links create the
    account only once clicked (proving you own the address). Sign-in links expire after
    15 minutes and work once. Opening a link shows a "Sign me in" button rather than signing
    in on GET, so email scanners that pre-fetch links can't use them up.
  - **Passkeys** (WebAuthn): add one or more on the Account page, then sign in with
    Face ID / Touch ID / Windows Hello / phone / security key. No email typing needed.
- **Your tools** – add, edit and remove tools with a category, condition and notes.
- **Public browsing** – anyone (even signed out) can browse and search all tools,
  filter by category, or show only tools that are available right now.
- **Shareable shed page** – `/users/:id` lists everything one person owns.
- **Borrow requests** – a signed-in user picks dates and sends a message.
  The owner approves or declines it on their dashboard, then clicks
  **Mark returned** when the tool comes back. Borrowers can cancel pending requests.
- **Status at a glance** – each tool shows *Available*, *Lent out until …* or *Overdue*.
  A tool can't be lent to two people at once.
- Email addresses are shown only between an owner and the person requesting, so they can arrange pickup.

## Running it
```bash
bundle install
bin/rails db:prepare db:seed   # demo users alice@example.com and bob@example.com
bin/rails server               # http://localhost:3000
```
In development, emails aren't really sent: open **http://localhost:3000/letter_opener**
to see them and click the sign-in links.

Passkeys only work on `localhost` or over HTTPS, and only on the origin they were created for.

## Tests
```bash
bin/rails test
```

## Data model
- `User` – name, email, `webauthn_id` (passkey user handle), `last_signed_in_at`
- `Passkey` – belongs to a user; credential id, public key, sign count, nickname
- `Tool` – belongs to a user; name, description, category, condition
- `BorrowRequest` – tool, borrower, start/due dates, message,
  status: `pending → approved → returned`, or `declined` / `cancelled`

## Production settings
| Env var | Purpose |
|---|---|
| `APP_ORIGIN` | Public URL, e.g. `https://tools.example.com`. Used for passkeys and for links in emails. |
| `MAILER_FROM` | Sender address for sign-in emails. |

You also need a real email service (SMTP, Postmark, etc.): set
`config.action_mailer.delivery_method` and its settings in `config/environments/production.rb`.
Changing the domain later invalidates existing passkeys (users can still sign in by email
and add new ones).
