# Chapter 16: Email with Messenger

## 1. Every App Sends Email

Signup confirmations. Password resets. Weekly digests. Invoices with PDF attachments. Every application needs email. Nobody enjoys building it.

SMTP configuration. Plain text fallbacks. Attachment encoding. Connection timeouts. The details pile up fast. Tina4's `Messenger` class absorbs all of it. Configure through `.env`. Create an instance. Send. In development mode, Messenger intercepts every outgoing email and displays it in the dev dashboard -- no real SMTP server required.

---

## 2. Messenger Configuration via .env

All email configuration lives in `.env`:

```bash
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

```bash
TINA4_MAIL_SMTP_HOST=smtp.gmail.com
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_USERNAME=your-email@gmail.com
TINA4_MAIL_SMTP_PASSWORD=your-app-password
TINA4_MAIL_SMTP_ENCRYPTION=tls
```

Gmail requires an "App Password" (not your regular password) when two-factor authentication is enabled.

**Mailgun:**

```bash
TINA4_MAIL_SMTP_HOST=smtp.mailgun.org
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_USERNAME=postmaster@mg.yourdomain.com
TINA4_MAIL_SMTP_PASSWORD=your-mailgun-smtp-password
TINA4_MAIL_SMTP_ENCRYPTION=tls
```

**SendGrid:**

```bash
TINA4_MAIL_SMTP_HOST=smtp.sendgrid.net
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_USERNAME=apikey
TINA4_MAIL_SMTP_PASSWORD=your-sendgrid-api-key
TINA4_MAIL_SMTP_ENCRYPTION=tls
```

---

## 3. Constructor Override Pattern

Different emails need different SMTP accounts. Transactional emails from one server. Marketing from another. Override the configuration in the constructor:

```typescript
import { Messenger } from "tina4-nodejs";

// Uses .env defaults
const mailer = new Messenger();

// Override specific settings
const marketingMailer = new Messenger({
    host: "smtp.mailgun.org",
    port: 587,
    username: "marketing@mg.yourdomain.com",
    password: "marketing-smtp-password",
    encryption: "tls",
    fromAddress: "newsletter@yourdomain.com",
    fromName: "My Store Newsletter"
});
```

Constructor arguments take priority over `.env` values. Any argument you omit falls back to the environment variable.

---

## 4. Sending Plain Text Email

The simplest email:

```typescript
import { Router, Messenger } from "tina4-nodejs";

Router.post("/api/contact", async (req, res) => {
    const body = req.body;
    const mailer = new Messenger();

    const result = await mailer.send({
        to: body.email,
        subject: "Contact Form Submission",
        body: `Name: ${body.name}\nEmail: ${body.email}\nMessage:\n${body.message}`
    });

    if (result.success) {
        return res.json({ message: "Email sent successfully" });
    }
    return res.status(500).json({ error: "Failed to send email", details: result.error });
});
```

```bash
curl -X POST http://localhost:7148/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "message": "I love your products!"}'
```

```json
{"message":"Email sent successfully"}
```

The `send()` method returns an object with three keys: `success` (boolean), `error` (string or null), and `messageId` (string or null).

### The send() Method Signature

```typescript
await mailer.send({
    to,                  // Recipient(s) -- string or array of strings
    subject,             // Email subject line
    body,                // Email body (plain text or HTML)
    html,                // If true, body is treated as HTML (default: false)
    text,                // Plain text alternative (when body is HTML)
    cc,                  // CC recipient(s) -- string or array
    bcc,                 // BCC recipient(s) -- string or array
    replyTo,             // Reply-To address
    attachments,         // Array of file paths or objects
    headers              // Additional email headers (object)
});
```

---

## 5. Sending HTML Email with Text Fallback

Most emails should carry HTML with a plain text fallback. Email clients that cannot render HTML display the text version instead:

```typescript
import { Messenger } from "tina4-nodejs";

const mailer = new Messenger();

const htmlBody = `
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
`;

const textBody = [
    "Hi Alice,",
    "",
    "Thank you for creating your account. We are excited to have you!",
    "",
    "Here is what you can do next:",
    "- Browse our product catalog: https://mystore.com/products",
    "- Set up your profile: https://mystore.com/profile",
    "- Check out our current deals: https://mystore.com/deals",
    "",
    "If you have any questions, reply to this email.",
    "",
    "Cheers,",
    "The My Store Team"
].join("\n");

const result = await mailer.send({
    to: "alice@example.com",
    subject: "Welcome to My Store!",
    body: htmlBody,
    html: true,
    text: textBody
});
```

Pass `html: true` to tell Messenger the body contains HTML. The `text` parameter provides the plain text alternative. Messenger builds a `multipart/alternative` message that carries both versions.

---

## 6. Adding Attachments

Attach files by providing their paths:

```typescript
import { Messenger } from "tina4-nodejs";

const mailer = new Messenger();

const result = await mailer.send({
    to: "accounting@example.com",
    subject: "Monthly Invoice #1042",
    body: "<h2>Invoice #1042</h2><p>Please find the invoice attached.</p>",
    html: true,
    attachments: [
        "/path/to/invoices/invoice-1042.pdf",
        "/path/to/reports/monthly-summary.csv"
    ]
});
```

Messenger reads each file, determines its MIME type, and encodes it for email transmission. Each entry can be a file path string or an object for more control.

### Attachments with Custom Names and Binary Content

```typescript
const result = await mailer.send({
    to: "alice@example.com",
    subject: "Your Export",
    body: "<p>Here is your data export.</p>",
    html: true,
    attachments: [
        {
            filename: "my-store-export.csv",
            content: csvBuffer,
            mime: "text/csv"
        }
    ]
});
```

The object format accepts `filename` (display name), `content` (Buffer or raw bytes), and `mime` (MIME type string). The recipient sees the file named `my-store-export.csv` regardless of how it was generated.

---

## 7. CC, BCC, and Reply-To

```typescript
import { Messenger } from "tina4-nodejs";

const mailer = new Messenger();

const result = await mailer.send({
    to: "alice@example.com",
    subject: "Team Meeting Notes",
    body: "<p>Here are the notes from today's meeting.</p>",
    html: true,
    cc: ["bob@example.com", "charlie@example.com"],
    bcc: ["manager@example.com"],
    replyTo: "alice@example.com"
});
```

- **cc**: Array of email addresses to carbon copy. All recipients see CC addresses.
- **bcc**: Array of email addresses to blind carbon copy. Recipients cannot see BCC addresses.
- **replyTo**: When the recipient clicks "Reply", this address fills the "To" field instead of the "From" address.

Both `cc` and `bcc` accept a single string or an array of strings.

---

## 8. Custom Headers

Messenger supports two methods for adding headers. The `addHeader()` method sets a default header on all emails sent by that instance. The `headers` property on `send()` sets headers for a single email.

### Default Headers on an Instance

```typescript
import { Messenger } from "tina4-nodejs";

const mailer = new Messenger();
mailer.addHeader("X-App-Name", "My Store");
mailer.addHeader("X-Environment", "production");

// Every email from this instance carries both headers
await mailer.send({ to: "alice@example.com", subject: "Test", body: "Hello" });
```

### Per-Email Headers

```typescript
const result = await mailer.send({
    to: "customer@example.com",
    subject: "Your Support Ticket #123",
    body: "We are looking into your issue.",
    replyTo: "support@mystore.com",
    headers: {
        "X-Ticket-Id": "123",
        "X-Priority": "1",
        "X-Mailer": "Tina4 Messenger"
    }
});
```

Per-email headers merge with default headers. If both define the same key, the per-email value wins.

Custom headers serve several purposes. Tracking headers like `X-Ticket-Id` let you correlate emails with support tickets. Priority headers influence some email clients' display. Bulk-sending headers like `Precedence: bulk` help mail servers classify newsletters.

| Header | Purpose |
|--------|---------|
| `X-Priority` | Email priority (1=high, 3=normal, 5=low) |
| `X-Mailer` | Identifies the sending application |
| `List-Unsubscribe` | One-click unsubscribe link (required for bulk email) |
| `X-Entity-Ref-ID` | Prevents threading in some email clients |
| `References` | Controls email threading |

---

## 9. Reading Inbox via IMAP

Messenger reads email through IMAP. Configure the IMAP server in `.env`:

```bash
TINA4_MAIL_IMAP_HOST=imap.example.com
TINA4_MAIL_IMAP_PORT=993
TINA4_MAIL_IMAP_USERNAME=support@example.com
TINA4_MAIL_IMAP_PASSWORD=your-imap-password
TINA4_MAIL_IMAP_ENCRYPTION=ssl
```

You can also override the IMAP host and port in the constructor:

```typescript
const mailer = new Messenger({ imapHost: "imap.gmail.com", imapPort: 993 });
```

### Listing Inbox Messages

The `getInbox()` method fetches message headers from the mailbox:

```typescript
import { Router, Messenger } from "tina4-nodejs";

Router.get("/api/inbox", async (req, res) => {
    const mailer = new Messenger();

    const emails = await mailer.getInbox({ limit: 20, offset: 0 });

    const messages = emails.map(email => ({
        uid: email.uid,
        from: email.from,
        subject: email.subject,
        date: email.date,
        snippet: email.snippet,
        seen: email.seen
    }));

    return res.json({ messages, count: messages.length });
});
```

```bash
curl http://localhost:7148/api/inbox
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

The `getInbox()` method returns messages newest-first. Each message contains `uid`, `subject`, `from`, `to`, `date`, `snippet` (first 150 characters of the body), and `seen` (boolean).

### Reading a Specific Message

```typescript
Router.get("/api/inbox/:uid", async (req, res) => {
    const mailer = new Messenger();
    const uid = req.params.uid;

    const email = await mailer.read(uid, { markRead: true });

    if (!email) {
        return res.status(404).json({ error: "Email not found" });
    }

    return res.json({
        uid: email.uid,
        from: email.from,
        to: email.to,
        cc: email.cc,
        subject: email.subject,
        date: email.date,
        bodyHtml: email.bodyHtml,
        bodyText: email.bodyText,
        attachments: (email.attachments ?? []).map(a => ({
            filename: a.filename,
            size: a.size,
            contentType: a.contentType
        }))
    });
});
```

The `read()` method fetches the full message including body and attachments. Pass `{ markRead: false }` to leave the message unread.

### Searching Messages

```typescript
Router.get("/api/inbox/search", async (req, res) => {
    const mailer = new Messenger();

    const results = await mailer.search({
        subject: req.query.q as string,
        sender: req.query.from as string,
        unseenOnly: req.query.unread === "true",
        limit: 20
    });

    return res.json({ messages: results, count: results.length });
});
```

The `search()` method accepts `subject`, `sender`, `since` (date string), `before`, and `unseenOnly` as filters. All filters combine with AND logic.

### Other IMAP Operations

```typescript
const mailer = new Messenger();

// Count unread messages
const count = await mailer.getUnreadCount();

// Mark a message as read
await mailer.markRead("12345");

// Mark a message as unread
await mailer.markUnread("12345");

// Delete a message
await mailer.deleteEmail("12345");

// List all mailbox folders
const folders = await mailer.getFolders();
// ["INBOX", "Sent", "Drafts", "Trash", "Spam"]
```

### Read from a Specific Folder

```typescript
const sent = await mailer.getInbox({ folder: "Sent", limit: 10 });
```

### Testing IMAP Connectivity

```typescript
const mailer = new Messenger();
const result = await mailer.testImapConnection();
if (result.success) {
    console.log("IMAP connection works");
} else {
    console.log(`IMAP failed: ${result.error}`);
}
```

---

## 10. Dev Mode: Email Interception

When `TINA4_DEBUG=true`, Tina4 intercepts all outgoing emails and stores them locally. No real recipients receive anything. No accidental emails during development.

Navigate to `/__dev` and look for the "Mail" section. You see:

- Every email "sent" during the current session
- The To, CC, and BCC addresses
- The subject and body (both HTML and plain text)
- Attachments (viewable inline)
- The timestamp

This is invaluable for testing email functionality without configuring a real SMTP server. Use `createMessenger()` instead of `new Messenger()` to get automatic dev-mode interception:

```typescript
import { createMessenger } from "tina4-nodejs";

const mailer = createMessenger();
// In dev mode: captures locally
// In production: sends via SMTP
```

### Disabling Interception

If you need to test real email delivery during development, override the interception:

```bash
TINA4_MAIL_INTERCEPT=false
```

With this set, emails reach real recipients even when `TINA4_DEBUG=true`. Use with caution -- you do not want to accidentally email your entire user base from a dev machine.

---

## 11. Using Templates for Email Content

Hardcoded HTML in string literals is ugly and hard to maintain. Templates fix this.

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

```typescript
import { Router, Messenger } from "tina4-nodejs";
import { Frond } from "tina4-nodejs/frond";
import crypto from "crypto";

Router.post("/api/register", async (req, res) => {
    const body = req.body;

    // Create user (database logic)
    const userId = 42;

    // Render the email template
    const emailData = {
        name: body.name,
        email: body.email,
        user_id: userId,
        signed_up_at: new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" }),
        base_url: process.env.APP_URL ?? "http://localhost:7148",
        app_name: "My Store",
        promo_code: "WELCOME10",
        unsubscribe_token: crypto.randomBytes(16).toString("hex")
    };

    const htmlBody = await Frond.render("emails/welcome.html", emailData);

    // Send the email
    const mailer = new Messenger();
    const result = await mailer.send({
        to: body.email,
        subject: `Welcome to My Store, ${body.name}!`,
        body: htmlBody,
        html: true,
        text: `Hi ${body.name},\n\nWelcome to My Store! Your account (#${userId}) has been created.\n\nCheers,\nThe My Store Team`
    });

    return res.status(201).json({
        message: "Registration successful",
        email_sent: result.success,
        user_id: userId
    });
});
```

```bash
curl -X POST http://localhost:7148/api/register \
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

With `TINA4_DEBUG=true`, the email appears in the dev dashboard instead of reaching a real inbox. Inspect the rendered HTML, check that template variables substituted, and verify the layout.

---

## 12. Sending Email via Queues

In production, never send email inside a route handler. The SMTP call blocks the response. Use the queue system from Chapter 12:

```typescript
import { Router, Queue, Messenger } from "tina4-nodejs";
import { Frond } from "tina4-nodejs/frond";

const emailQueue = new Queue({ topic: "emails" });

// In the route handler, just queue the email
Router.post("/api/register", async (req, res) => {
    const userId = 42; // Simulated

    emailQueue.push({
        template: "emails/welcome.html",
        to: req.body.email,
        subject: `Welcome to My Store, ${req.body.name}!`,
        data: {
            name: req.body.name,
            email: req.body.email,
            user_id: userId,
            signed_up_at: "March 22, 2026",
            base_url: "http://localhost:7148",
            app_name: "My Store",
            promo_code: "WELCOME10"
        }
    });

    return res.status(201).json({ message: "Registration successful", user_id: userId });
});

// The consumer sends the actual email
emailQueue.process(async (job) => {
    const { template, to, subject, data } = job.payload as any;

    const frond = new Frond("src/templates");
    const htmlBody = frond.render(template, data);

    const mailer = new Messenger();
    const result = await mailer.send({ to, subject, body: htmlBody, html: true });

    if (!result.success) {
        console.log(`Email failed: ${result.message}`);
        job.fail(result.message);
        return;
    }

    console.log(`Email sent to ${to}`);
    job.complete();
});
```

The route handler returns in under 50 milliseconds. The queue worker sends the email on its own timeline. If the SMTP server is down, retries happen automatically.

---

## 13. Exercise: Build a Contact Form with Email Notification

Build a contact form that sends an email notification when submitted.

### Requirements

1. Create a `GET /contact` page that renders a contact form with fields: name, email, subject, and message

2. Create a `POST /contact` endpoint that:
   - Validates all fields are present
   - Sends an email notification to the site admin (`admin@example.com`)
   - The email should include all form fields, formatted in HTML
   - Shows a flash message on success
   - Redirects back to the contact page

3. Create an email template at `src/templates/emails/contact-notification.html` that formats the contact submission

### Test with:

```bash
# View the form
curl http://localhost:7148/contact

# Submit the form
curl -X POST http://localhost:7148/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Bob", "email": "bob@example.com", "subject": "Product inquiry", "message": "Do you ship internationally?"}'

# Check the dev dashboard for the intercepted email
# Navigate to http://localhost:7148/__dev
```

---

## 14. Solution

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

Create `src/routes/contact.ts`:

```typescript
import { Router, Messenger } from "tina4-nodejs";
import { Frond } from "tina4-nodejs/frond";

Router.get("/contact", async (req, res) => {
    const flash = req.session._flash ?? null;
    delete req.session._flash;
    return res.html("contact.html", { flash });
});

Router.post("/contact", async (req, res) => {
    const body = req.body;

    // Validate
    const errors: string[] = [];
    if (!body.name) errors.push("Name is required");
    if (!body.email) errors.push("Email is required");
    if (!body.subject) errors.push("Subject is required");
    if (!body.message) errors.push("Message is required");

    if (errors.length > 0) {
        req.session._flash = { type: "error", message: `Please fill in all fields: ${errors.join(", ")}` };
        return res.redirect("/contact");
    }

    // Render the email template
    const htmlBody = await Frond.render("emails/contact-notification.html", {
        name: body.name,
        email: body.email,
        subject: body.subject,
        message: body.message,
        submitted_at: new Date().toLocaleString()
    });

    // Send the email
    const mailer = new Messenger();
    const adminEmail = process.env.ADMIN_EMAIL ?? "admin@example.com";

    const result = await mailer.send({
        to: adminEmail,
        subject: `Contact Form: ${body.subject}`,
        body: htmlBody,
        html: true,
        replyTo: body.email,
        text: `Contact form submission from ${body.name} (${body.email}):\n\nSubject: ${body.subject}\n\nMessage:\n${body.message}`
    });

    if (result.success) {
        req.session._flash = {
            type: "success",
            message: "Thank you for your message! We will get back to you shortly."
        };
    } else {
        req.session._flash = {
            type: "error",
            message: "Sorry, there was a problem sending your message. Please try again later."
        };
    }

    return res.redirect("/contact");
});
```

**Testing:**

1. Open `http://localhost:7148/contact` in your browser
2. Fill in the form and submit
3. You should see a green "Thank you" flash message
4. Open `http://localhost:7148/__dev` to see the intercepted email
5. The email shows the sender details, subject, message, and formatted HTML

**API test:**

```bash
curl -X POST http://localhost:7148/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Bob", "email": "bob@example.com", "subject": "Product inquiry", "message": "Do you ship internationally?"}' \
  -c cookies.txt -b cookies.txt
```

The response is a `302` redirect to `/contact`. Follow the redirect to see the flash message:

```bash
curl http://localhost:7148/contact -b cookies.txt
```

The HTML response includes the success flash message.

---

## 15. Gotchas

### 1. Gmail Blocks "Less Secure" Apps

**Problem:** Sending via Gmail fails with "Authentication failed" or "Username and Password not accepted".

**Cause:** Gmail blocks SMTP access from apps that do not use OAuth2 by default. Your regular password will not work when two-factor authentication is enabled.

**Fix:** Generate an "App Password" in your Google Account settings (Security > 2-Step Verification > App Passwords). Use this 16-character password as `TINA4_MAIL_SMTP_PASSWORD`. This is separate from your regular Google password.

### 2. Emails Go to Spam

**Problem:** Emails land in the recipient's spam folder.

**Cause:** Your sending domain lacks proper DNS records (SPF, DKIM, DMARC) or you send from a free email provider (Gmail, Yahoo).

**Fix:** Use a dedicated sending domain with proper DNS records. Set up SPF, DKIM, and DMARC records. Use a transactional email service -- Mailgun, SendGrid, or Amazon SES -- that handles email reputation for you.

### 3. HTML Email Looks Broken

**Problem:** The email looks fine in Gmail but broken in Outlook or Apple Mail.

**Cause:** Email clients have different HTML/CSS support. CSS flexbox, grid, and many modern properties do not work in email.

**Fix:** Use inline styles (not external stylesheets or `<style>` blocks). Use table-based layouts for complex designs. Test with an email preview tool. Keep it simple -- most transactional emails do not need elaborate designs.

### 4. Attachment File Not Found

**Problem:** `mailer.send()` returns an error about a missing file.

**Cause:** The attachment path is relative or incorrect. The file does not exist at the specified location.

**Fix:** Use absolute paths for attachments. Verify the file exists before calling `send()`: `if (!fs.existsSync(path)) { ... }`. If the file is generated dynamically (a PDF, for example), make sure the generation completes before sending.

### 5. Dev Mode Silently Intercepts Emails

**Problem:** You configured SMTP but no emails arrive. No errors either.

**Cause:** `TINA4_DEBUG=true` intercepts all emails and stores them in the dev dashboard. The email never reaches the SMTP server.

**Fix:** Check the dev dashboard at `/__dev` for intercepted emails. If you want to send real emails during development, set `TINA4_MAIL_INTERCEPT=false`. Remove this setting before committing.

### 6. Email Template Variables Not Substituted

**Problem:** The email body shows `{{ name }}` literally instead of the user's name.

**Cause:** You passed the raw template file content instead of rendering it through the template engine.

**Fix:** Use `Frond.render("emails/template.html", data)` to render the template with variables substituted. Do not read the file with `fs.readFileSync()` -- that gives you the raw template source.

### 7. Connection Timeout on Send

**Problem:** `mailer.send()` hangs for 30 seconds and then fails with a timeout error.

**Cause:** The SMTP server is unreachable from your network. The port may be blocked by a firewall, or the hostname may be wrong.

**Fix:** Test SMTP connectivity with `mailer.testConnection()`. Verify the hostname, port, and encryption settings. Check that your firewall allows outbound connections on the SMTP port. If you sit behind a corporate firewall, port 587 or 465 might be blocked -- ask your network administrator.

### 8. IMAP Host Not Configured

**Problem:** Calling `mailer.getInbox()` throws `MessengerError: IMAP host not configured`.

**Cause:** You did not set `TINA4_MAIL_IMAP_HOST` in `.env` or pass `imapHost` to the constructor.

**Fix:** Add `TINA4_MAIL_IMAP_HOST=imap.example.com` and `TINA4_MAIL_IMAP_PORT=993` to `.env`. The IMAP host is separate from the SMTP host -- many providers use different hostnames for sending and reading.
