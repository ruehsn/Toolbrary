# Tool Share

A small Rails 8 app for keeping track of your tools and letting other people see
what you have so they can ask to borrow it.

## Features
- **Accounts** – sign up / sign in / password reset (Rails 8 built-in authentication).
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
bin/rails db:prepare db:seed   # seed creates alice@example.com / bob@example.com, password "password123"
bin/rails server               # http://localhost:3000
```

## Tests
```bash
bin/rails test
```

## Data model
- `User` – name, email, password
- `Tool` – belongs to a user; name, description, category, condition
- `BorrowRequest` – tool, borrower, start/due dates, message,
  status: `pending → approved → returned`, or `declined` / `cancelled`

Password-reset emails need a mailer configured in production (`config/environments/production.rb`).
