# Chapter 13: Email with Messenger

## 1. Every App Sends Email

Signup confirmations. Password resets. Weekly digests. Attachments, HTML templates, reliable delivery. Every application needs email. Nobody enjoys implementing it. SMTP configuration. Plain text fallbacks. Attachment encoding. Connection timeouts. The details pile up fast.

Tina4's `Messenger` class absorbs that complexity. Configure via `.env`. Create an instance. Send. In development mode, emails are intercepted and shown in the dev dashboard -- no real SMTP server needed.

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

### Common Provider Configurations

**Gmail:**

```env
TINA4_MAIL_SMTP_HOST=smtp.gmail.com
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_USERNAME=your-email@gmail.com
TINA4_MAIL_SMTP_PASSWORD=your-app-password
TINA4_MAIL_SMTP_ENCRYPTION=tls
```

Note: Gmail requires an "App Password" (not your regular password) when two-factor authentication is enabled.

**Mailgun:**

```env
TINA4_MAIL_SMTP_HOST=smtp.mailgun.org
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_USERNAME=postmaster@mg.yourdomain.com
TINA4_MAIL_SMTP_PASSWORD=your-mailgun-smtp-password
TINA4_MAIL_SMTP_ENCRYPTION=tls
```

**SendGrid:**

```env
TINA4_MAIL_SMTP_HOST=smtp.sendgrid.net
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_USERNAME=apikey
TINA4_MAIL_SMTP_PASSWORD=your-sendgrid-api-key
TINA4_MAIL_SMTP_ENCRYPTION=tls
```

---

## 3. Constructor Override Pattern

If you need to use different SMTP settings for different purposes (transactional emails from one account, marketing from another), override the configuration in the constructor:

```python
from tina4_python.messenger import Messenger

# Uses .env defaults
mailer = Messenger()

# Override specific settings
marketing_mailer = Messenger(
    host="smtp.mailgun.org",
    port=587,
    username="marketing@mg.yourdomain.com",
    password="marketing-smtp-password",
    encryption="tls",
    from_address="newsletter@yourdomain.com",
    from_name="My Store Newsletter"
)
```

The constructor accepts keyword arguments that override `.env` values. Unspecified keys fall back to `.env`.

---

## 4. Sending Plain Text Email

The simplest email you can send:

```python
from tina4_python.core.router import post
from tina4_python.messenger import Messenger

@post("/api/contact")
async def contact_form(request, response):
    body = request.body

    mailer = Messenger()

    result = mailer.send(
        to=body["email"],
        subject="Contact Form Submission",
        body=f"Name: {body['name']}\n"
             f"Email: {body['email']}\n"
             f"Message:\n{body['message']}"
    )

    if result["success"]:
        return response({"message": "Email sent successfully"})

    return response({"error": "Failed to send email", "details": result["error"]}, 500)
```

```bash
curl -X POST http://localhost:7145/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "message": "I love your products!"}'
```

```json
{"message":"Email sent successfully"}
```

The `send()` method returns a dict with `"success"` (boolean) and `"error"` (string, only present on failure).

### The send() Method

```python
mailer.send(to, subject, body, **options)
```

- **to**: Recipient email address (string)
- **subject**: Email subject line (string)
- **body**: Email body content (string -- plain text or HTML)
- **options**: Optional keyword arguments (see below)

---

## 5. Sending HTML Email with Text Fallback

Most emails should be HTML with a plain text fallback for email clients that do not render HTML:

```python
from tina4_python.messenger import Messenger

mailer = Messenger()

html_body = """
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
        <p>If you have any questions, reply to this email and we will get back to you within 24 hours.</p>
        <p>Cheers,<br>The My Store Team</p>
    </div>
    <div style="background: #f5f5f5; padding: 12px; text-align: center; font-size: 12px; color: #888;">
        <p>You received this because you signed up at mystore.com</p>
    </div>
</body>
</html>
"""

text_body = (
    "Hi Alice,\n\n"
    "Thank you for creating your account. We are excited to have you!\n\n"
    "Here is what you can do next:\n"
    "- Browse our product catalog: https://mystore.com/products\n"
    "- Set up your profile: https://mystore.com/profile\n"
    "- Check out our current deals: https://mystore.com/deals\n\n"
    "If you have any questions, reply to this email.\n\n"
    "Cheers,\nThe My Store Team"
)

result = mailer.send(
    to="alice@example.com",
    subject="Welcome to My Store!",
    body=html_body,
    text_body=text_body
)
```

The `text_body` option provides the plain text fallback. Email clients that cannot render HTML will show the text version instead.

---

## 6. Adding Attachments

Attach files by providing their paths:

```python
from tina4_python.messenger import Messenger

mailer = Messenger()

result = mailer.send(
    to="accounting@example.com",
    subject="Monthly Invoice #1042",
    body="<h2>Invoice #1042</h2><p>Please find the invoice attached.</p>",
    attachments=[
        "/path/to/invoices/invoice-1042.pdf",
        "/path/to/reports/monthly-summary.csv"
    ]
)
```

Each attachment is the absolute file path. Tina4 reads the file, determines the MIME type, and encodes it for email transmission.

### Inline Attachments with Custom Names

```python
result = mailer.send(
    to="alice@example.com",
    subject="Your Export",
    body="<p>Here is your data export.</p>",
    attachments=[
        {
            "path": "/tmp/export-20260322.csv",
            "name": "my-store-export.csv"
        }
    ]
)
```

The recipient sees the file named `my-store-export.csv` regardless of its actual filename on disk.

---

## 7. CC and BCC

```python
from tina4_python.messenger import Messenger

mailer = Messenger()

result = mailer.send(
    to="alice@example.com",
    subject="Team Meeting Notes",
    body="<p>Here are the notes from today's meeting.</p>",
    cc=["bob@example.com", "charlie@example.com"],
    bcc=["manager@example.com"],
    reply_to="alice@example.com"
)
```

- **cc**: List of email addresses to carbon copy. All recipients can see CC addresses.
- **bcc**: List of email addresses to blind carbon copy. Recipients cannot see BCC addresses.
- **reply_to**: When the recipient clicks "Reply", this address is used instead of the "From" address.

---

## 8. Reading Inbox via IMAP

Tina4's Messenger can also read emails via IMAP:

```env
TINA4_MAIL_IMAP_HOST=imap.example.com
TINA4_MAIL_IMAP_PORT=993
TINA4_MAIL_IMAP_USERNAME=support@example.com
TINA4_MAIL_IMAP_PASSWORD=your-imap-password
TINA4_MAIL_IMAP_ENCRYPTION=ssl
```

```python
from tina4_python.core.router import get
from tina4_python.messenger import Messenger

@get("/api/inbox")
async def get_inbox(request, response):
    mailer = Messenger()

    emails = mailer.get_inbox(limit=20, unread_only=True)

    messages = []
    for email in emails:
        messages.append({
            "id": email["id"],
            "from": email["from"],
            "subject": email["subject"],
            "date": email["date"],
            "preview": email["text_body"][:200],
            "has_attachments": bool(email.get("attachments"))
        })

    return response({"messages": messages, "count": len(messages)})
```

```bash
curl http://localhost:7145/api/inbox
```

```json
{
  "messages": [
    {
      "id": "12345",
      "from": "customer@example.com",
      "subject": "Order question",
      "date": "2026-03-22T10:30:00+00:00",
      "preview": "Hi, I have a question about my recent order...",
      "has_attachments": false
    }
  ],
  "count": 1
}
```

### Reading a Specific Email

```python
@get("/api/inbox/{email_id}")
async def get_email(request, response):
    mailer = Messenger()
    email_id = request.params["email_id"]

    email = mailer.get_message(email_id)

    if email is None:
        return response({"error": "Email not found"}, 404)

    return response({
        "id": email["id"],
        "from": email["from"],
        "to": email["to"],
        "subject": email["subject"],
        "date": email["date"],
        "html_body": email["html_body"],
        "text_body": email["text_body"],
        "attachments": [
            {"name": a["name"], "size": a["size"], "type": a["type"]}
            for a in email.get("attachments", [])
        ]
    })
```

---

## 9. Dev Mode: Email Interception

When `TINA4_DEBUG=true`, Tina4 intercepts all outgoing emails and shows them in the dev dashboard. No real recipients receive anything. No accidental emails during development.

Navigate to `/__dev` and look for the "Mail" section. You will see:

- Every email that was "sent" during the current session
- The To, CC, and BCC addresses
- The subject and body (both HTML and plain text)
- Attachments (viewable inline)
- The timestamp

This is invaluable for testing email functionality without configuring a real SMTP server or polluting someone's inbox.

### Disabling Interception

If you need to test real email delivery during development, override the interception:

```env
TINA4_MAIL_INTERCEPT=false
```

With this set, emails are sent to real recipients even when `TINA4_DEBUG=true`. Use with caution -- you do not want to accidentally email your entire user base from a dev machine.

---

## 10. Using Templates for Email Content

Hardcoded HTML in Python strings is ugly and hard to maintain. Templates fix this:

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
        <p>Your account has been created successfully. Here are your details:</p>

        <table style="width: 100%; border-collapse: collapse; margin: 16px 0;">
            <tr>
                <td style="padding: 8px; border-bottom: 1px solid #eee; font-weight: bold;">Email</td>
                <td style="padding: 8px; border-bottom: 1px solid #eee;">{{ email }}</td>
            </tr>
            <tr>
                <td style="padding: 8px; border-bottom: 1px solid #eee; font-weight: bold;">Account ID</td>
                <td style="padding: 8px; border-bottom: 1px solid #eee;">#{{ user_id }}</td>
            </tr>
            <tr>
                <td style="padding: 8px; border-bottom: 1px solid #eee; font-weight: bold;">Signed Up</td>
                <td style="padding: 8px; border-bottom: 1px solid #eee;">{{ signed_up_at }}</td>
            </tr>
        </table>

        <p>Get started by exploring:</p>
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
        <p><a href="{{ base_url }}/unsubscribe?token={{ unsubscribe_token }}" style="color: #888;">Unsubscribe</a></p>
    </div>
</body>
</html>
```

### Rendering and Sending

```python
import os
import secrets
from datetime import datetime
from tina4_python.core.router import post, template
from tina4_python.messenger import Messenger

@post("/api/register")
async def register_user(request, response):
    body = request.body

    # Create user (database logic)
    user_id = 42

    # Render the email template
    email_data = {
        "name": body["name"],
        "email": body["email"],
        "user_id": user_id,
        "signed_up_at": datetime.now().strftime("%B %d, %Y"),
        "base_url": os.getenv("APP_URL", "http://localhost:7145"),
        "app_name": "My Store",
        "promo_code": "WELCOME10",
        "unsubscribe_token": secrets.token_hex(16)
    }

    html_body = template("emails/welcome.html", **email_data)

    # Send the email
    mailer = Messenger()
    result = mailer.send(
        to=body["email"],
        subject=f"Welcome to My Store, {body['name']}!",
        body=html_body,
        text_body=f"Hi {body['name']},\n\nWelcome to My Store! "
                  f"Your account (#{user_id}) has been created.\n\n"
                  f"Cheers,\nThe My Store Team"
    )

    return response({
        "message": "Registration successful",
        "email_sent": result["success"],
        "user_id": user_id
    }, 201)
```

```bash
curl -X POST http://localhost:7145/api/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "securePass123"}'
```

```json
{
  "message": "Registration successful",
  "email_sent": true,
  "user_id": 42
}
```

With `TINA4_DEBUG=true`, the email appears in the dev dashboard instead of being sent. You can inspect the rendered HTML, check that template variables were substituted correctly, and verify the layout.

---

## 11. Sending Email via Queues

In production, never send email inside a route handler. The SMTP call blocks the response. Use the queue system from Chapter 11:

```python
from tina4_python.core.router import post, template
from tina4_python.queue import Queue
from tina4_python.messenger import Messenger

# In the route handler, just queue the email
@post("/api/register")
async def register_user(request, response):
    body = request.body
    user_id = 42  # Simulated

    queue = Queue(topic="emails")
    queue.push({
        "template": "emails/welcome.html",
        "to": body["email"],
        "subject": f"Welcome to My Store, {body['name']}!",
        "data": {
            "name": body["name"],
            "email": body["email"],
            "user_id": user_id,
            "signed_up_at": "March 22, 2026",
            "base_url": "http://localhost:7145",
            "app_name": "My Store",
            "promo_code": "WELCOME10"
        }
    })

    return response({"message": "Registration successful", "user_id": user_id}, 201)


# The consumer sends the actual email
@Queue.consume("emails")
async def send_email_job(job):
    payload = job.payload

    html_body = template(payload["template"], **payload["data"])

    mailer = Messenger()
    result = mailer.send(
        to=payload["to"],
        subject=payload["subject"],
        body=html_body
    )

    if not result["success"]:
        print(f"Email failed: {result['error']}")
        return False  # Retry

    print(f"Email sent to {payload['to']}")
    return True
```

The route handler returns in under 50 milliseconds. The queue worker sends the email on its own timeline. If the SMTP server is down, retries happen automatically.

---

## 12. Exercise: Build a Contact Form with Email Notification

Build a contact form that sends an email notification when submitted.

### Requirements

1. Create a `GET /contact` page that renders a contact form with fields: name, email, subject, and message

2. Create a `POST /contact` endpoint that:
   - Validates all fields are present
   - Sends an email notification to the site admin (`admin@example.com`)
   - The email should include all form fields, nicely formatted
   - Shows a flash message on success
   - Redirects back to the contact page

3. Create an email template at `src/templates/emails/contact-notification.html` that formats the contact submission

### Test with:

```bash
# View the form
curl http://localhost:7145/contact

# Submit the form
curl -X POST http://localhost:7145/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Bob", "email": "bob@example.com", "subject": "Product inquiry", "message": "Do you ship internationally?"}'

# Check the dev dashboard for the intercepted email
# Navigate to http://localhost:7145/__dev
```

---

## 13. Solution

Create `src/templates/emails/contact-notification.html`:

```html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
    <div style="background: #1a1a2e; color: white; padding: 16px; text-align: center;">
        <h2 style="margin: 0;">New Contact Form Submission</h2>
    </div>
    <div style="padding: 20px; background: white;">
        <table style="width: 100%; border-collapse: collapse;">
            <tr>
                <td style="padding: 10px; border-bottom: 1px solid #eee; font-weight: bold; width: 100px;">From</td>
                <td style="padding: 10px; border-bottom: 1px solid #eee;">{{ name }} ({{ email }})</td>
            </tr>
            <tr>
                <td style="padding: 10px; border-bottom: 1px solid #eee; font-weight: bold;">Subject</td>
                <td style="padding: 10px; border-bottom: 1px solid #eee;">{{ subject }}</td>
            </tr>
            <tr>
                <td style="padding: 10px; border-bottom: 1px solid #eee; font-weight: bold;">Date</td>
                <td style="padding: 10px; border-bottom: 1px solid #eee;">{{ submitted_at }}</td>
            </tr>
        </table>

        <div style="margin-top: 16px; padding: 16px; background: #f8f9fa; border-radius: 4px;">
            <h3 style="margin-top: 0;">Message</h3>
            <p style="white-space: pre-wrap;">{{ message }}</p>
        </div>

        <p style="margin-top: 16px; color: #888; font-size: 12px;">
            Reply directly to this email to respond to {{ name }} at {{ email }}.
        </p>
    </div>
</body>
</html>
```

Create `src/templates/contact.html`:

```html
{% extends "base.html" %}

{% block title %}Contact Us{% endblock %}

{% block content %}
    <h1>Contact Us</h1>

    {% if flash %}
        <div style="padding: 12px; border-radius: 4px; margin-bottom: 16px;
            {% if flash.type == 'success' %}background: #d4edda; color: #155724;{% endif %}
            {% if flash.type == 'error' %}background: #f8d7da; color: #721c24;{% endif %}">
            {{ flash.message }}
        </div>
    {% endif %}

    <form method="POST" action="/contact" style="max-width: 500px;">
        <div style="margin-bottom: 12px;">
            <label for="name" style="display: block; margin-bottom: 4px; font-weight: bold;">Name</label>
            <input type="text" name="name" id="name" required
                   style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
        </div>

        <div style="margin-bottom: 12px;">
            <label for="email" style="display: block; margin-bottom: 4px; font-weight: bold;">Email</label>
            <input type="email" name="email" id="email" required
                   style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
        </div>

        <div style="margin-bottom: 12px;">
            <label for="subject" style="display: block; margin-bottom: 4px; font-weight: bold;">Subject</label>
            <input type="text" name="subject" id="subject" required
                   style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
        </div>

        <div style="margin-bottom: 12px;">
            <label for="message" style="display: block; margin-bottom: 4px; font-weight: bold;">Message</label>
            <textarea name="message" id="message" rows="6" required
                      style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;"></textarea>
        </div>

        <button type="submit"
                style="padding: 10px 20px; background: #1a1a2e; color: white; border: none; border-radius: 4px; cursor: pointer;">
            Send Message
        </button>
    </form>
{% endblock %}
```

Create `src/routes/contact.py`:

```python
import os
from datetime import datetime
from tina4_python.core.router import get, post, template
from tina4_python.messenger import Messenger

@get("/contact")
async def contact_page(request, response):
    flash = request.session.get("_flash")
    if flash:
        del request.session["_flash"]

    return response(template("contact.html", flash=flash))


@post("/contact")
async def contact_submit(request, response):
    body = request.body

    # Validate
    errors = []
    if not body.get("name"):
        errors.append("Name is required")
    if not body.get("email"):
        errors.append("Email is required")
    if not body.get("subject"):
        errors.append("Subject is required")
    if not body.get("message"):
        errors.append("Message is required")

    if errors:
        request.session["_flash"] = {
            "type": "error",
            "message": "Please fill in all fields: " + ", ".join(errors)
        }
        return response.redirect("/contact")

    # Render the email template
    html_body = template("emails/contact-notification.html",
        name=body["name"],
        email=body["email"],
        subject=body["subject"],
        message=body["message"],
        submitted_at=datetime.now().strftime("%B %d, %Y at %I:%M %p")
    )

    # Send the email
    mailer = Messenger()
    admin_email = os.getenv("ADMIN_EMAIL", "admin@example.com")

    result = mailer.send(
        to=admin_email,
        subject=f"Contact Form: {body['subject']}",
        body=html_body,
        reply_to=body["email"],
        text_body=f"Contact form submission from {body['name']} ({body['email']}):\n\n"
                  f"Subject: {body['subject']}\n\n"
                  f"Message:\n{body['message']}"
    )

    if result["success"]:
        request.session["_flash"] = {
            "type": "success",
            "message": "Thank you for your message! We will get back to you shortly."
        }
    else:
        request.session["_flash"] = {
            "type": "error",
            "message": "Sorry, there was a problem sending your message. Please try again later."
        }

    return response.redirect("/contact")
```

**Testing:**

1. Open `http://localhost:7145/contact` in your browser
2. Fill in the form and submit
3. You should see a green "Thank you" flash message
4. Open `http://localhost:7145/__dev` to see the intercepted email
5. The email should show the sender details, subject, message, and formatted HTML

**API test:**

```bash
curl -X POST http://localhost:7145/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Bob", "email": "bob@example.com", "subject": "Product inquiry", "message": "Do you ship internationally?"}' \
  -c cookies.txt -b cookies.txt
```

The response is a `302` redirect to `/contact`. Follow the redirect to see the flash message:

```bash
curl http://localhost:7145/contact -b cookies.txt
```

The HTML response includes the success flash message.

---

## 14. Gotchas

### 1. Gmail Blocks "Less Secure" Apps

**Problem:** Sending via Gmail fails with "Authentication failed" or "Username and Password not accepted".

**Cause:** Gmail blocks SMTP access from apps that do not use OAuth2 by default. Using your regular password will not work if two-factor authentication is enabled.

**Fix:** Generate an "App Password" in your Google Account settings (Security > 2-Step Verification > App Passwords). Use this 16-character password as `TINA4_MAIL_SMTP_PASSWORD`. This is separate from your regular Google password.

### 2. Emails Go to Spam

**Problem:** Emails are delivered but land in the recipient's spam folder.

**Cause:** Your sending domain lacks proper DNS records (SPF, DKIM, DMARC) or you are sending from a free email provider (Gmail, Yahoo).

**Fix:** Use a dedicated sending domain with proper DNS records. Set up SPF, DKIM, and DMARC records. Use a transactional email service like Mailgun, SendGrid, or Amazon SES that handles email reputation for you.

### 3. HTML Email Looks Broken

**Problem:** The email looks fine in Gmail but broken in Outlook or Apple Mail.

**Cause:** Email clients have wildly different HTML/CSS support. CSS flexbox, grid, and many modern properties do not work in email.

**Fix:** Use inline styles (not external stylesheets or `<style>` blocks). Use table-based layouts for complex designs. Test with an email preview tool. Keep it simple -- most transactional emails do not need elaborate designs.

### 4. Attachment File Not Found

**Problem:** `Messenger.send()` returns an error about a missing file.

**Cause:** The attachment path is relative or incorrect. The file does not exist at the specified location.

**Fix:** Use absolute paths for attachments. Verify the file exists before calling `send()`: `if not os.path.exists(path): ...`. If the file is generated dynamically (like a PDF), make sure the generation completes before sending.

### 5. Dev Mode Silently Intercepts Emails

**Problem:** You set up SMTP correctly but no emails arrive. No errors either.

**Cause:** `TINA4_DEBUG=true` intercepts all emails and shows them in the dev dashboard. The email is never sent to the SMTP server.

**Fix:** Check the dev dashboard at `/__dev` for intercepted emails. If you want to send real emails during development, set `TINA4_MAIL_INTERCEPT=false`. Remember to remove this setting before committing.

### 6. Email Template Variables Not Substituted

**Problem:** The email body shows `{{ name }}` literally instead of the user's name.

**Cause:** You passed the raw template file content instead of rendering it through the template engine. The template engine was not invoked.

**Fix:** Use `template("emails/template.html", **data)` to render the template with variables substituted. Do not read the file with `open()` -- that gives you the raw template source.

### 7. Connection Timeout on Send

**Problem:** `Messenger.send()` hangs for 30 seconds and then fails with a timeout error.

**Cause:** The SMTP server is unreachable from your network, the port is blocked by a firewall, or the hostname is wrong.

**Fix:** Test SMTP connectivity: `telnet smtp.example.com 587`. Verify the hostname, port, and encryption settings. Check that your firewall allows outbound connections on the SMTP port. If you are behind a corporate firewall, port 587 or 465 might be blocked -- ask your network administrator.
