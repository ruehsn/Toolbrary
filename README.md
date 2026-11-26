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
- **🤖 Works with any AI assistant (MCP)** – the app is an MCP server at `/mcp`. Connect Claude,
  Cursor, VS Code, a local model, or any other MCP client with a personal token from
  **Account → AI assistants**, then just ask: "what drills can I borrow?", "check the ladder out to Sam
  until Friday", "approve Alice's request". The app needs no AI provider of its own.
- **📷 Add tools from photos** – upload up to 10 photos of a bench, pegboard or shelf, then pick who
  analyses them:
  - **your own AI assistant** (default): ask it to "catalogue my Tool Share photo imports"; it fetches
    each photo over MCP and submits what it sees, or
  - **the built-in AI** (optional, needs `ANTHROPIC_API_KEY`).

  Either way you get each tool's name, category, condition, description and a cropped photo to
  review, edit and untick before adding them all at once.
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

To connect an AI assistant locally, create a token under Account → AI assistants and use
`http://localhost:3000/mcp`. To also enable the optional built-in photo analysis:
`ANTHROPIC_API_KEY=sk-ant-... bin/rails server`.

Passkeys only work on `localhost` or over HTTPS, and only on the origin they were created for.

## MCP server

Streamable HTTP (stateless, JSON responses) at `POST /mcp`, built on the official
[`mcp` Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk). Authenticate with
`Authorization: Bearer tsk_…`. Tokens are created and revoked under Account → AI assistants,
and only their SHA-256 digests are stored.

| Tool | What it does |
|---|---|
| `search_tools`, `get_tool`, `list_categories` | Browse the community catalogue |
| `my_shed` | My tools, requests waiting for me, what I've lent and borrowed |
| `add_tool`, `update_tool` | Manage my tools |
| `check_out_tool`, `check_in_tool` | Lend in person / record a return |
| `respond_to_borrow_request`, `request_to_borrow` | The borrowing workflow |
| `list_photo_imports`, `get_import_photo`, `submit_import_items` | Catalogue tools from uploaded photos |

Code: `app/mcp/` (one class per tool) and `app/controllers/mcp_controller.rb`.
Example (Claude Code):
```bash
claude mcp add --transport http tool-share https://tools.example.com/mcp --header "Authorization: Bearer tsk_..."
```
Web-only connectors that require OAuth (claude.ai, ChatGPT) aren't supported yet. They need an
OAuth 2.1 authorization server, which would be the next step.

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
- `ToolImport` – uploaded photos + detected items. Status `awaiting_assistant → ready → completed` (user's
  assistant via MCP) or `pending → processing → ready → completed` / `failed` (built-in `ToolPhotoAnalyzer`).
- `ApiToken` – personal MCP tokens (digest only)

## Production settings
| Env var | Purpose |
|---|---|
| `APP_ORIGIN` | Public URL, e.g. `https://tools.example.com`. Used for passkeys and for links in emails. |
| `MAILER_FROM` | Sender address for sign-in emails. |
| `ANTHROPIC_API_KEY` | Optional. Enables the *built-in* AI photo analysis (one Claude API call per photo). Without it, users' own assistants do the analysis over MCP. |

Background jobs (AI import, emails) use Solid Queue in production: run `bin/jobs`, or set
`SOLID_QUEUE_IN_PUMA=1` to run them inside the web server. Uploaded photos are stored on local
disk (`storage/`); for multiple servers, configure S3 or similar in `config/storage.yml`.

You also need a real email service (SMTP, Postmark, etc.): set
`config.action_mailer.delivery_method` and its settings in `config/environments/production.rb`.
Changing the domain later invalidates existing passkeys (users can still sign in by email
and add new ones).
