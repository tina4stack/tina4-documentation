# Chapter 13: Email with Messenger

## 1. Every App Sends Email

Signup confirmations. Password resets. Weekly digests. Attachments, HTML templates, reliable delivery. Every application needs email. Nobody enjoys building it. SMTP configuration. Plain text fallbacks. Attachment encoding. Connection timeouts. Bounce handling. The details compound.

Tina4's `Messenger` class owns all of this. Configure via `.env`. Create an instance. Send. In development mode, emails are intercepted and shown in the dev dashboard -- inspect them without touching a real SMTP server.

---

## 2. Messenger Configuration via .env

All email configuration lives in `.env`:

```env
TINA4_MAIL_SMTP_HOST=smtp.example.com
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_USERNAME=your-email@example.com
TINA4_MAIL_SMTP_PASSWORD=your-app-password
TINA4_MAIL_SMTP_ENCRYPTION=tls
TINA4_MAIL_FROM_ADDRESS=noreply@example.com
TINA4_MAIL_FROM_NAME=My Store
```

| Variable | Description | Common Values |
|----------|-------------|---------------|
| `TINA4_MAIL_SMTP_HOST` | SMTP server hostname | `smtp.gmail.com`, `smtp.mailgun.org`, `smtp.sendgrid.net` |
| `TINA4_MAIL_SMTP_PORT` | SMTP port | `587` (TLS), `465` (SSL), `25` (unencrypted) |
| `TINA4_MAIL_SMTP_USERNAME` | Login username | Usually your email address |
| `TINA4_MAIL_SMTP_PASSWORD` | Login password or app-specific password | App passwords for Gmail |
| `TINA4_MAIL_SMTP_ENCRYPTION` | Encryption method | `tls` (recommended), `ssl`, `none` |
| `TINA4_MAIL_FROM_ADDRESS` | Default "From" address | `noreply@yourdomain.com` |
| `TINA4_MAIL_FROM_NAME` | Default "From" display name | `My Store`, `Acme Corp` |

---

## 3. Sending a Simple Email

```ruby
Tina4::Router.post("/api/contact") do |request, response|
  body = request.body

  mail = Tina4::Messenger.new
  mail.to = body["email"]
  mail.subject = "Thanks for reaching out!"
  mail.body = "Hi #{body['name']},\n\nWe received your message and will get back to you within 24 hours.\n\nBest regards,\nMy Store Team"
  mail.send

  response.json({ message: "Email sent successfully" })
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

---

## 4. HTML Emails with Templates

Use Frond templates for rich HTML emails:

```ruby
Tina4::Router.post("/api/send-welcome") do |request, response|
  body = request.body

  mail = Tina4::Messenger.new
  mail.to = body["email"]
  mail.subject = "Welcome to My Store, #{body['name']}!"
  mail.html_template = "emails/welcome.html"
  mail.template_data = {
    name: body["name"],
    login_url: "https://mystore.com/login",
    year: Time.now.year
  }
  mail.send

  response.json({ message: "Welcome email sent" })
end
```

Create `src/templates/emails/welcome.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; background: #f5f5f5; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; padding: 32px; }
        .header { text-align: center; padding-bottom: 20px; border-bottom: 1px solid #eee; }
        .btn { display: inline-block; padding: 12px 24px; background: #2d8f2d; color: white; text-decoration: none; border-radius: 4px; }
        .footer { text-align: center; color: #999; font-size: 12px; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Welcome, {{ name }}!</h1>
        </div>
        <p>Thanks for signing up. Your account is ready to go.</p>
        <p style="text-align: center;">
            <a href="{{ login_url }}" class="btn">Log In to Your Account</a>
        </p>
        <div class="footer">
            <p>&copy; {{ year }} My Store. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
```

---

## 5. Attachments

```ruby
mail = Tina4::Messenger.new
mail.to = "alice@example.com"
mail.subject = "Your Invoice"
mail.body = "Please find your invoice attached."
mail.attach("/path/to/invoice.pdf")
mail.attach("/path/to/receipt.png")
mail.send
```

### Multiple Attachments

```ruby
mail = Tina4::Messenger.new
mail.to = "alice@example.com"
mail.subject = "Monthly Report"
mail.body = "Here are this month's reports."
mail.attach("/reports/sales.pdf")
mail.attach("/reports/analytics.xlsx")
mail.attach("/reports/summary.csv")
mail.send
```

---

## 6. CC and BCC

```ruby
mail = Tina4::Messenger.new
mail.to = "alice@example.com"
mail.cc = ["bob@example.com", "charlie@example.com"]
mail.bcc = ["manager@example.com"]
mail.subject = "Project Update"
mail.body = "Here is the latest project update..."
mail.send
```

---

## 7. Dev Mode: Email Interception

When `TINA4_DEBUG=true`, emails are not sent to real SMTP servers. Instead, they are intercepted and stored in the dev dashboard. Navigate to `/__dev` and click "Emails" to see:

- Recipient, subject, and timestamp
- Full HTML preview
- Plain text fallback
- Attachments list
- Headers

This means you can test email functionality without configuring SMTP during development.

---

## 8. Queuing Emails

For production, always queue emails instead of sending them synchronously:

```ruby
Tina4::Router.post("/api/register") do |request, response|
  body = request.body

  # Create user...
  user_id = 42

  # Queue the email instead of sending directly
  Tina4::Queue.produce("send-email", {
    to: body["email"],
    subject: "Welcome to My Store!",
    template: "emails/welcome.html",
    data: { name: body["name"], login_url: "https://mystore.com/login" }
  })

  response.json({ message: "Registration successful", user_id: user_id }, 201)
end

# Consumer that sends queued emails
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

---

## 9. Reply-To and Custom Headers

```ruby
mail = Tina4::Messenger.new
mail.to = "customer@example.com"
mail.reply_to = "support@mystore.com"
mail.subject = "Your Support Ticket #123"
mail.body = "We are looking into your issue..."
mail.add_header("X-Ticket-Id", "123")
mail.add_header("X-Priority", "1")
mail.send
```

---

## 10. Exercise: Build an Email Notification System

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

## 11. Solution

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

## 12. Gotchas

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

**Problem:** `mail.attach("/path/to/file.pdf")` raises a file not found error.

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
