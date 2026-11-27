# Default categories everywhere; demo users and tools in development only.
# Demo data: bin/rails db:seed   (sign in via email link; see /letter_opener in development)
Category.create_defaults!
return unless Rails.env.development?

alice = User.find_or_create_by!(email_address: "alice@example.com") { |u| u.name = "Alice" }
bob   = User.find_or_create_by!(email_address: "bob@example.com")   { |u| u.name = "Bob" }

[
  [ alice, "Cordless drill (18V)", "Power tools", "Good", "Two batteries + charger included." ],
  [ alice, "Extension ladder 6m", "Ladders & access", "Fair", "Heavy — bring a helper to collect." ],
  [ alice, "Hedge trimmer", "Garden & yard", "Good", nil ],
  [ bob,   "Circular saw", "Power tools", "New", "Please use your own blades." ],
  [ bob,   "Pipe wrench set", "Plumbing", "Worn", nil ],
  [ bob,   "Laser level", "Measuring", "Good", "Takes 2x AA batteries." ]
].each do |owner, name, category, condition, description|
  owner.tools.find_or_create_by!(name: name) do |t|
    t.assign_attributes(category: Category.find_or_create_by_name(category), condition:, description:,
                        replacement_url: (name == "Laser level" ? "https://www.example.com/laser-level" : nil))
  end
end

ladder = Tool.find_by!(name: "Extension ladder 6m")
ladder.borrow_requests.find_or_create_by!(borrower: bob) do |r|
  r.assign_attributes(status: "approved", start_date: Date.current - 2, due_date: Date.current + 5, message: "Gutter cleaning!")
end
saw = Tool.find_by!(name: "Circular saw")
saw.borrow_requests.find_or_create_by!(borrower: alice) do |r|
  r.assign_attributes(start_date: Date.current + 1, due_date: Date.current + 3, message: "Need it for a deck project this weekend.")
end
puts "Seeded #{User.count} users, #{Tool.count} tools, #{BorrowRequest.count} requests."
