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
- **Your tools** – add, edit and remove tools with photos, a category, condition, notes and
  an optional **replacement link** ("🛒 Buy a replacement"). Every tool also gets a
  "Search for a replacement" shopping link.
- **Categories** – shared, emoji-labelled categories (Power tools, Garden & yard, …). Browse by
  category chips, see counts on `/categories`, and add new ones from the tool form or the categories page.
- **Check in / check out** – lend a tool in person: record who has it (a member by email, or
  anyone by name), and when it's due. **Check in** when it comes back. Each tool keeps a
  check-out history for its owner.
- **📷 Add tools from photos (AI)** – upload up to 10 photos of a bench, pegboard or shelf.
  Claude finds every tool, drafts the name, category, condition and description, and gives a
  bounding box that's used to crop a photo of each one. You review, edit, untick, then add them all at once.
- **Public browsing** – anyone (even signed out) can browse and search all tools,
  filter by category, or show only tools that are available right now.
- **Shareable shed page** – `/users/:id` lists everything one person owns.
- **Borrow requests** – a signed-in user picks dates and sends a message.
  The owner clicks **Approve & check out** or declines it on their dashboard, then
  **Check in** when the tool comes back. Borrowers can cancel pending requests.
- **Status at a glance** – each tool shows *Available*, *Lent out until …* or *Overdue*.
  A tool can't be lent to two people at once.
- Email addresses are shown only between an owner and the person requesting, so they can arrange pickup.

## Running it
Needs **libvips** for photos (`apt install libvips42` / `brew install vips`).
```bash
bundle install
bin/rails db:prepare db:seed   # demo users alice@example.com and bob@example.com
bin/rails server               # http://localhost:3000
```
In development, emails aren't really sent: open **http://localhost:3000/letter_opener**
to see them and click the sign-in links.

To try AI photo import locally, set an Anthropic API key first:
`ANTHROPIC_API_KEY=sk-ant-... bin/rails server`. Without it, everything else works and the
import page says it isn't configured.

Passkeys only work on `localhost` or over HTTPS, and only on the origin they were created for.

## Tests
```bash
bin/rails test
```

## Data model
- `User` – name, email, `webauthn_id` (passkey user handle), `last_signed_in_at`
- `Passkey` – belongs to a user; credential id, public key, sign count, nickname
- `Category` – name, emoji icon
- `Tool` – belongs to a user and a category; name, description, condition, replacement URL, photos (Active Storage)
- `BorrowRequest` – a loan: tool, borrower (member) *or* borrower name (non-member), dates, message,
  status: `pending → approved (checked out) → returned (checked in)`, or `declined` / `cancelled`
- `ToolImport` – uploaded photos + the AI's detected items, status `pending → processing → ready → completed` / `failed`.
  Analysis runs in `AnalyzeToolImportJob` → `ToolPhotoAnalyzer` (Claude Opus 5.5 vision, JSON-schema output).

## Production settings
| Env var | Purpose |
|---|---|
| `APP_ORIGIN` | Public URL, e.g. `https://tools.example.com`. Used for passkeys and for links in emails. |
| `MAILER_FROM` | Sender address for sign-in emails. |
| `ANTHROPIC_API_KEY` | Enables AI photo import. Each photo is one Claude API call. |

Background jobs (AI import, emails) use Solid Queue in production: run `bin/jobs`, or set
`SOLID_QUEUE_IN_PUMA=1` to run them inside the web server. Uploaded photos are stored on local
disk (`storage/`); for multiple servers, configure S3 or similar in `config/storage.yml`.

You also need a real email service (SMTP, Postmark, etc.): set
`config.action_mailer.delivery_method` and its settings in `config/environments/production.rb`.
Changing the domain later invalidates existing passkeys (users can still sign in by email
and add new ones).
