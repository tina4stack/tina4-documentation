# Chapter 13: Email with Messenger

## 1. Every App Sends Email

Signup confirmations. Password resets. Weekly digests. Invoices with PDF attachments. Every application needs email. Nobody enjoys building it.

SMTP configuration. Plain text fallbacks. Attachment encoding. Connection timeouts. Bounce handling. The details compound. Tina4's `Messenger` class owns all of it. Configure through `.env`. Create an instance. Send. In development mode, Messenger intercepts every outgoing email and displays it in the dev dashboard -- no real SMTP server required.

---

## 2. Messenger Configuration via .env

All email configuration lives in `.env`:

```env
TINA4_MAIL_HOST=smtp.example.com
TINA4_MAIL_PORT=587
TINA4_MAIL_USERNAME=your-email@example.com
TINA4_MAIL_PASSWORD=your-app-password
TINA4_MAIL_ENCRYPTION=tls
TINA4_MAIL_FROM=noreply@example.com
TINA4_MAIL_FROM_NAME=My Store
```

| Variable | Description | Common Values |
|----------|-------------|---------------|
| `TINA4_MAIL_HOST` | SMTP server hostname | `smtp.gmail.com`, `smtp.mailgun.org`, `smtp.sendgrid.net` |
| `TINA4_MAIL_PORT` | SMTP port | `587` (TLS), `465` (SSL), `25` (unencrypted) |
| `TINA4_MAIL_USERNAME` | Login username | Usually your email address |
| `TINA4_MAIL_PASSWORD` | Login password or app-specific password | App passwords for Gmail |
| `TINA4_MAIL_ENCRYPTION` | Encryption method | `tls` (recommended), `ssl`, `none` |
| `TINA4_MAIL_FROM` | Default "From" address | `noreply@yourdomain.com` |
| `TINA4_MAIL_FROM_NAME` | Default "From" display name | `My Store`, `Acme Corp` |

Messenger also accepts legacy `SMTP_*` prefixed variables as fallback. The `TINA4_MAIL_*` prefix takes priority.

### Common Provider Configurations

**Gmail:**

```env
TINA4_MAIL_HOST=smtp.gmail.com
TINA4_MAIL_PORT=587
TINA4_MAIL_USERNAME=your-email@gmail.com
TINA4_MAIL_PASSWORD=your-app-password
TINA4_MAIL_ENCRYPTION=tls
```

Gmail requires an "App Password" (not your regular password) when two-factor authentication is enabled.

**Mailgun:**

```env
TINA4_MAIL_HOST=smtp.mailgun.org
TINA4_MAIL_PORT=587
TINA4_MAIL_USERNAME=postmaster@mg.yourdomain.com
TINA4_MAIL_PASSWORD=your-mailgun-smtp-password
TINA4_MAIL_ENCRYPTION=tls
```

**SendGrid:**

```env
TINA4_MAIL_HOST=smtp.sendgrid.net
TINA4_MAIL_PORT=587
TINA4_MAIL_USERNAME=apikey
TINA4_MAIL_PASSWORD=your-sendgrid-api-key
TINA4_MAIL_ENCRYPTION=tls
```

---

## 3. Constructor Override Pattern

Different emails need different SMTP accounts. Transactional emails from one server. Marketing from another. Override the configuration in the constructor:

```ruby
# Uses .env defaults
mailer = Tina4::Messenger.new

# Override specific settings
marketing_mailer = Tina4::Messenger.new(
  host: "smtp.mailgun.org",
  port: 587,
  username: "marketing@mg.yourdomain.com",
  password: "marketing-smtp-password",
  encryption: "tls",
  from_address: "newsletter@yourdomain.com",
  from_name: "My Store Newsletter"
)
```

Constructor arguments take priority over `.env` values. Any argument you omit falls back to the environment variable.

---

## 4. Sending Plain Text Email

The simplest email:

```ruby
Tina4::Router.post("/api/contact") do |request, response|
  body = request.body

  mail = Tina4::Messenger.new
  result = mail.send(
    to: body["email"],
    subject: "Contact Form Submission",
    body: "Name: #{body['name']}\nEmail: #{body['email']}\nMessage:\n#{body['message']}"
  )

  if result[:success]
    response.json({ message: "Email sent successfully" })
  else
    response.json({ error: "Failed to send email", details: result[:message] }, 500)
  end
end
```

```bash
curl -X POST http://localhost:7147/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "message": "Hello!"}'
```

```json
{"message":"Email sent successfully"}
```

The `send` method returns a hash with three keys: `success` (boolean), `message` (string), and `id` (message ID string or nil).

### The send Method Signature

```ruby
mail.send(
  to:,              # Recipient(s) -- string or array of strings
  subject:,         # Email subject line
  body:,            # Email body (plain text or HTML)
  html: false,      # If true, body is treated as HTML
  text: nil,        # Plain text alternative (when body is HTML)
  cc: [],           # CC recipient(s) -- string or array
  bcc: [],          # BCC recipient(s) -- string or array
  reply_to: nil,    # Reply-To address
  attachments: [],  # List of file paths or hashes
  headers: {}       # Additional email headers (hash)
)
```

---

## 5. Sending HTML Email with Text Fallback

Most emails should carry HTML with a plain text fallback. Email clients that cannot render HTML display the text version instead:

```ruby
mail = Tina4::Messenger.new

html_body = <<~HTML
  <html>
  <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <div style="background: #1a1a2e; color: white; padding: 20px; text-align: center;">
          <h1 style="margin: 0;">Welcome to My Store!</h1>
      </div>
      <div style="padding: 20px;">
          <p>Hi Alice,</p>
          <p>Thank you for creating your account. We are excited to have you!</p>
          <p>Here is what you can do next:</p>
          <ul>
              <li>Browse our <a href="https://mystore.com/products">product catalog</a></li>
              <li>Set up your <a href="https://mystore.com/profile">profile</a></li>
              <li>Check out our <a href="https://mystore.com/deals">current deals</a></li>
          </ul>
          <p>Cheers,<br>The My Store Team</p>
      </div>
      <div style="background: #f5f5f5; padding: 12px; text-align: center; font-size: 12px; color: #888;">
          <p>You received this because you signed up at mystore.com</p>
      </div>
  </body>
  </html>
HTML

text_body = <<~TEXT
  Hi Alice,

  Thank you for creating your account. We are excited to have you!

  Here is what you can do next:
  - Browse our product catalog: https://mystore.com/products
  - Set up your profile: https://mystore.com/profile
  - Check out our current deals: https://mystore.com/deals

  Cheers,
  The My Store Team
TEXT

result = mail.send(
  to: "alice@example.com",
  subject: "Welcome to My Store!",
  body: html_body,
  html: true,
  text: text_body
)
```

Pass `html: true` to tell Messenger the body contains HTML. The `text` parameter provides the plain text alternative. Messenger builds a `multipart/alternative` message that carries both versions.

---

## 6. Adding Attachments

Attach files by providing their paths:

```ruby
mail = Tina4::Messenger.new

result = mail.send(
  to: "accounting@example.com",
  subject: "Monthly Invoice #1042",
  body: "<h2>Invoice #1042</h2><p>Please find the invoice attached.</p>",
  html: true,
  attachments: [
    "/path/to/invoices/invoice-1042.pdf",
    "/path/to/reports/monthly-summary.csv"
  ]
)
```

Messenger reads each file, determines its MIME type, and encodes it for email transmission.

### Multiple Attachments

```ruby
mail = Tina4::Messenger.new
result = mail.send(
  to: "alice@example.com",
  subject: "Monthly Report",
  body: "Here are this month's reports.",
  attachments: [
    "/reports/sales.pdf",
    "/reports/analytics.xlsx",
    "/reports/summary.csv"
  ]
)
```

---

## 7. CC, BCC, and Reply-To

```ruby
mail = Tina4::Messenger.new

result = mail.send(
  to: "alice@example.com",
  subject: "Team Meeting Notes",
  body: "<p>Here are the notes from today's meeting.</p>",
  html: true,
  cc: ["bob@example.com", "charlie@example.com"],
  bcc: ["manager@example.com"],
  reply_to: "alice@example.com"
)
```

- **cc**: List of email addresses to carbon copy. All recipients see CC addresses.
- **bcc**: List of email addresses to blind carbon copy. Recipients cannot see BCC addresses.
- **reply_to**: When the recipient clicks "Reply", this address fills the "To" field instead of the "From" address.

Both `cc` and `bcc` accept a single string or an array of strings.

---

## 8. Custom Headers

Messenger supports custom headers through the `headers` parameter on `send`:

```ruby
result = mail.send(
  to: "customer@example.com",
  subject: "Your Support Ticket #123",
  body: "We are looking into your issue.",
  reply_to: "support@mystore.com",
  headers: {
    "X-Ticket-Id" => "123",
    "X-Priority" => "1",
    "X-Mailer" => "Tina4 Messenger"
  }
)
```

Custom headers serve several purposes. Tracking headers like `X-Ticket-Id` let you correlate emails with support tickets. Priority headers influence some email clients' display. Bulk-sending headers like `Precedence: bulk` help mail servers classify newsletters.

---

## 9. Reading Inbox via IMAP

Messenger reads email through IMAP. Configure the IMAP server in `.env`:

```env
TINA4_MAIL_IMAP_HOST=imap.example.com
TINA4_MAIL_IMAP_PORT=993
```

Messenger reuses `TINA4_MAIL_USERNAME` and `TINA4_MAIL_PASSWORD` for IMAP authentication. You can also override the IMAP host and port in the constructor:

```ruby
mailer = Tina4::Messenger.new(imap_host: "imap.gmail.com", imap_port: 993)
```

### Listing Inbox Messages

The `inbox` method fetches message headers from the mailbox:

```ruby
Tina4::Router.get("/api/inbox") do |request, response|
  mailer = Tina4::Messenger.new

  emails = mailer.inbox(limit: 20, offset: 0)

  messages = emails.map do |email|
    {
      uid: email[:uid],
      from: email[:from],
      subject: email[:subject],
      date: email[:date],
      snippet: email[:snippet],
      seen: email[:seen]
    }
  end

  response.json({ messages: messages, count: messages.length })
end
```

```bash
curl http://localhost:7147/api/inbox
```

```json
{
  "messages": [
    {
      "uid": "12345",
      "from": "customer@example.com",
      "subject": "Order question",
      "date": "2026-03-22T10:30:00+00:00",
      "snippet": "Hi, I have a question about my recent order...",
      "seen": false
    }
  ],
  "count": 1
}
```

The `inbox` method returns messages newest-first. Each message contains `uid`, `subject`, `from`, `to`, `date`, `snippet` (first 150 characters of the body), and `seen` (boolean).

### Reading a Specific Message

```ruby
Tina4::Router.get("/api/inbox/{uid}") do |request, response|
  mailer = Tina4::Messenger.new
  uid = request.params["uid"]

  email = mailer.read(uid, mark_read: true)

  if email.nil?
    return response.json({ error: "Email not found" }, 404)
  end

  response.json({
    uid: email[:uid],
    from: email[:from],
    to: email[:to],
    cc: email[:cc],
    subject: email[:subject],
    date: email[:date],
    body_html: email[:body_html],
    body_text: email[:body_text],
    attachments: (email[:attachments] || []).map { |a|
      { filename: a[:filename], size: a[:size], content_type: a[:content_type] }
    }
  })
end
```

The `read` method fetches the full message including body and attachments. Pass `mark_read: false` to leave the message unread.

### Searching Messages

```ruby
Tina4::Router.get("/api/inbox/search") do |request, response|
  mailer = Tina4::Messenger.new

  results = mailer.search(
    subject: request.params["q"],
    sender: request.params["from"],
    unseen_only: request.params["unread"] == "true",
    limit: 20
  )

  response.json({ messages: results, count: results.length })
end
```

The `search` method accepts `subject`, `sender`, `since` (date string), `before`, and `unseen_only` as filters. All filters combine with AND logic.

### Other IMAP Operations

```ruby
mailer = Tina4::Messenger.new

# Count unread messages
count = mailer.unread

# List all mailbox folders
folders = mailer.folders
# ["INBOX", "Sent", "Drafts", "Trash", "Spam"]
```

---

## 10. Dev Mode: Email Interception

When `TINA4_DEBUG=true`, Tina4 intercepts all outgoing emails and stores them locally. No real recipients receive anything. No accidental emails during development.

Navigate to `/__dev` and click "Emails" to see:

- Recipient, subject, and timestamp
- Full HTML preview
- Plain text fallback
- Attachments list
- Headers

This means you can test email functionality without configuring SMTP during development.

### Disabling Interception

If you need to test real email delivery during development, override the interception:

```env
TINA4_MAIL_INTERCEPT=false
```

With this set, emails reach real recipients even when `TINA4_DEBUG=true`. Use with caution -- you do not want to accidentally email your entire user base from a dev machine.

---

## 11. Using Templates for Email Content

Hardcoded HTML in Ruby strings is ugly and hard to maintain. Templates fix this.

Create `src/templates/emails/welcome.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
</head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #f5f5f5; padding: 20px;">
    <div style="background: #1a1a2e; color: white; padding: 24px; text-align: center; border-radius: 8px 8px 0 0;">
        <h1 style="margin: 0; font-size: 24px;">Welcome, {{ name }}!</h1>
    </div>
    <div style="background: white; padding: 24px; border-radius: 0 0 8px 8px;">
        <p>Hi {{ name }},</p>
        <p>Your account has been created. Here are your details:</p>

        <table style="width: 100%; border-collapse: collapse; margin: 16px 0;">
            <tr>
                <td style="padding: 8px; border-bottom: 1px solid #eee; font-weight: bold;">Email</td>
                <td style="padding: 8px; border-bottom: 1px solid #eee;">{{ email }}</td>
            </tr>
            <tr>
                <td style="padding: 8px; border-bottom: 1px solid #eee; font-weight: bold;">Account ID</td>
                <td style="padding: 8px; border-bottom: 1px solid #eee;">#{{ user_id }}</td>
            </tr>
        </table>

        <p>Get started:</p>
        <ul>
            <li><a href="{{ base_url }}/products" style="color: #1a1a2e;">Our product catalog</a></li>
            <li><a href="{{ base_url }}/profile" style="color: #1a1a2e;">Your profile settings</a></li>
        </ul>

        {% if promo_code %}
            <div style="background: #d4edda; padding: 16px; border-radius: 4px; margin: 16px 0;">
                <strong>Special offer!</strong> Use code <code>{{ promo_code }}</code> for 10% off your first order.
            </div>
        {% endif %}

        <p>Cheers,<br>The {{ app_name }} Team</p>
    </div>

    <div style="text-align: center; padding: 12px; color: #888; font-size: 12px;">
        <p>You received this because you signed up at {{ app_name }}.</p>
    </div>
</body>
</html>
```

### Rendering and Sending

Use `html_template` and `template_data` on the Messenger instance:

```ruby
Tina4::Router.post("/api/register") do |request, response|
  body = request.body

  # Create user (database logic)
  user_id = 42

  mail = Tina4::Messenger.new
  mail.to = body["email"]
  mail.subject = "Welcome to My Store, #{body['name']}!"
  mail.html_template = "emails/welcome.html"
  mail.template_data = {
    name: body["name"],
    email: body["email"],
    user_id: user_id,
    base_url: ENV["APP_URL"] || "http://localhost:7147",
    app_name: "My Store",
    promo_code: "WELCOME10"
  }
  mail.send

  response.json({ message: "Registration successful", user_id: user_id }, 201)
end
```

```bash
curl -X POST http://localhost:7147/api/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "securePass123"}'
```

```json
{
  "message": "Registration successful",
  "user_id": 42
}
```

With `TINA4_DEBUG=true`, the email appears in the dev dashboard instead of reaching a real inbox. Inspect the rendered HTML, check that template variables substituted, and verify the layout.

---

## 12. Sending Email via Queues

In production, never send email inside a route handler. The SMTP call blocks the response. Use the queue system:

```ruby
# In the route handler, queue the email
Tina4::Router.post("/api/register") do |request, response|
  body = request.body
  user_id = 42  # Simulated

  Tina4::Queue.produce("send-email", {
    to: body["email"],
    subject: "Welcome to My Store, #{body['name']}!",
    template: "emails/welcome.html",
    data: {
      name: body["name"],
      email: body["email"],
      user_id: user_id,
      base_url: "http://localhost:7147",
      app_name: "My Store",
      promo_code: "WELCOME10"
    }
  })

  response.json({ message: "Registration successful", user_id: user_id }, 201)
end

# The consumer sends the actual email
Tina4::Queue.consume("send-email") do |job|
  mail = Tina4::Messenger.new
  mail.to = job.payload["to"]
  mail.subject = job.payload["subject"]

  if job.payload["template"]
    mail.html_template = job.payload["template"]
    mail.template_data = job.payload["data"] || {}
  else
    mail.body = job.payload["body"] || ""
  end

  mail.send
  true
end
```

The route handler returns in under 50 milliseconds. The queue worker sends the email on its own timeline. If the SMTP server is down, retries happen automatically.

---

## 13. Exercise: Build an Email Notification System

Build an email system that sends different types of notifications.

### Requirements

1. `POST /api/notify/welcome` -- Send a welcome email with an HTML template
2. `POST /api/notify/order` -- Send an order confirmation with order details
3. `POST /api/notify/reset` -- Send a password reset email with a token link

Each endpoint should queue the email rather than sending it directly.

### Test with:

```bash
curl -X POST http://localhost:7147/api/notify/welcome \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com"}'

curl -X POST http://localhost:7147/api/notify/order \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "order_id": 101, "total": 159.98}'

curl -X POST http://localhost:7147/api/notify/reset \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "reset_token": "abc123def456"}'
```

---

## 14. Solution

Create `src/routes/notifications.rb`:

```ruby
# @noauth
Tina4::Router.post("/api/notify/welcome") do |request, response|
  body = request.body

  Tina4::Queue.produce("send-email", {
    to: body["email"],
    subject: "Welcome to My Store, #{body['name']}!",
    template: "emails/welcome.html",
    data: { name: body["name"], login_url: "https://mystore.com/login", year: Time.now.year }
  })

  response.json({ message: "Welcome email queued" })
end

# @noauth
Tina4::Router.post("/api/notify/order") do |request, response|
  body = request.body

  Tina4::Queue.produce("send-email", {
    to: body["email"],
    subject: "Order Confirmation ##{body['order_id']}",
    template: "emails/order-confirmation.html",
    data: { order_id: body["order_id"], total: body["total"] }
  })

  response.json({ message: "Order confirmation email queued" })
end

# @noauth
Tina4::Router.post("/api/notify/reset") do |request, response|
  body = request.body

  Tina4::Queue.produce("send-email", {
    to: body["email"],
    subject: "Password Reset Request",
    template: "emails/password-reset.html",
    data: { reset_url: "https://mystore.com/reset?token=#{body['reset_token']}" }
  })

  response.json({ message: "Password reset email queued" })
end
```

---

## 15. Gotchas

### 1. Gmail Requires App Passwords

**Problem:** Gmail login fails with "authentication error".

**Fix:** Enable 2FA on your Google account, then generate an App Password at https://myaccount.google.com/apppasswords. Use the app password, not your regular password.

### 2. Emails Go to Spam

**Problem:** Emails arrive in the spam folder.

**Fix:** Set up SPF, DKIM, and DMARC DNS records for your domain. Use a reputable email service like Mailgun, SendGrid, or Postmark.

### 3. HTML Email Rendering Differences

**Problem:** Your email looks different in Gmail, Outlook, and Apple Mail.

**Fix:** Use inline CSS. Avoid flexbox and grid. Use tables for layout. Test with a tool like Litmus or Email on Acid.

### 4. Attachment File Not Found

**Problem:** `attachments: ["/path/to/file.pdf"]` raises a file not found error.

**Fix:** Use absolute paths. Relative paths resolve from the working directory, which may differ in production.

### 5. SMTP Connection Timeout

**Problem:** Sending email hangs for 30 seconds and then times out.

**Fix:** Check your SMTP host, port, and encryption settings. Common mistake: using port 587 with SSL instead of TLS.

### 6. Dev Mode Emails Disappear on Restart

**Problem:** Intercepted emails in the dev dashboard vanish when you restart the server.

**Fix:** This is expected. Dev mode stores emails in memory. For persistent storage, configure a real SMTP server.

### 7. Unicode Characters Display as Question Marks

**Problem:** Non-ASCII characters (accents, CJK) show as `?` in the email.

**Fix:** Tina4 sets UTF-8 encoding by default. If you are constructing raw headers, make sure you include `Content-Type: text/html; charset=utf-8`.

### 8. IMAP Connection Fails

**Problem:** `inbox` or `read` raises a connection error.

**Fix:** Verify `TINA4_MAIL_IMAP_HOST` and `TINA4_MAIL_IMAP_PORT` in `.env`. Gmail uses `imap.gmail.com` on port `993`. Make sure your email provider allows IMAP access -- some providers disable it by default.
