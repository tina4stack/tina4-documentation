# Chapter 13: Email with Messenger

## 1. Every App Sends Email

Signup confirmations. Password resets. Weekly digests. Every application sends email.

Tina4's `Messenger` class handles SMTP configuration, HTML templates, attachments, and delivery. In development mode, Tina4 intercepts all outgoing emails and shows them in the dev dashboard. Nothing leaves the server until you say so.

---

## 2. Messenger Configuration via .env

```env
TINA4_MAIL_SMTP_HOST=smtp.example.com
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_USERNAME=your-email@example.com
TINA4_MAIL_SMTP_PASSWORD=your-app-password
TINA4_MAIL_SMTP_ENCRYPTION=tls
TINA4_MAIL_FROM_ADDRESS=noreply@example.com
TINA4_MAIL_FROM_NAME=My Store
```

### Common Provider Configurations

**Gmail:**
```env
TINA4_MAIL_SMTP_HOST=smtp.gmail.com
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_ENCRYPTION=tls
```

**SendGrid:**
```env
TINA4_MAIL_SMTP_HOST=smtp.sendgrid.net
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_USERNAME=apikey
TINA4_MAIL_SMTP_PASSWORD=your-sendgrid-api-key
```

---

## 3. Constructor Override Pattern

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

---

## 4. Sending Plain Text Email

```typescript
import { Router, Messenger } from "tina4-nodejs";

Router.post("/api/contact", async (req, res) => {
    const body = req.body;
    const mailer = new Messenger();

    const result = await mailer.send(
        body.email,
        "Contact Form Submission",
        `Name: ${body.name}\nEmail: ${body.email}\nMessage:\n${body.message}`
    );

    if (result.success) {
        return res.json({ message: "Email sent successfully" });
    }
    return res.status(500).json({ error: "Failed to send email", details: result.error });
});
```

---

## 5. Sending HTML Email with Text Fallback

```typescript
const result = await mailer.send(
    "alice@example.com",
    "Welcome to My Store!",
    htmlBody,
    { textBody: textBody }
);
```

---

## 6. Adding Attachments

```typescript
const result = await mailer.send(
    "accounting@example.com",
    "Monthly Invoice #1042",
    "<h2>Invoice #1042</h2><p>Please find the invoice attached.</p>",
    {
        attachments: [
            "/path/to/invoices/invoice-1042.pdf",
            { path: "/tmp/export.csv", name: "my-store-export.csv" }
        ]
    }
);
```

---

## 7. CC and BCC

```typescript
const result = await mailer.send(
    "alice@example.com",
    "Team Meeting Notes",
    "<p>Here are the notes.</p>",
    {
        cc: ["bob@example.com", "charlie@example.com"],
        bcc: ["manager@example.com"],
        replyTo: "alice@example.com"
    }
);
```

---

## 8. Reading Inbox via IMAP

```env
TINA4_MAIL_IMAP_HOST=imap.example.com
TINA4_MAIL_IMAP_PORT=993
TINA4_MAIL_IMAP_USERNAME=support@example.com
TINA4_MAIL_IMAP_PASSWORD=your-imap-password
TINA4_MAIL_IMAP_ENCRYPTION=ssl
```

```typescript
Router.get("/api/inbox", async (req, res) => {
    const mailer = new Messenger();
    const emails = await mailer.getInbox({ limit: 20, unreadOnly: true });

    const messages = emails.map(email => ({
        id: email.id,
        from: email.from,
        subject: email.subject,
        date: email.date,
        preview: email.textBody.substring(0, 200),
        has_attachments: email.attachments.length > 0
    }));

    return res.json({ messages, count: messages.length });
});
```

---

## 9. Dev Mode: Email Interception

When `TINA4_DEBUG=true`, Tina4 catches all outgoing emails and holds them in the dev dashboard. Navigate to `/__dev` to inspect them. No email reaches a real inbox during development.

Override with `TINA4_MAIL_INTERCEPT=false` if you need real delivery in debug mode.

---

## 10. Using Templates for Email Content

Create `src/templates/emails/welcome.html` with Frond template syntax, then render and send:

```typescript
import { Router, Messenger, Frond } from "tina4-nodejs";

Router.post("/api/register", async (req, res) => {
    const body = req.body;
    const userId = 42;

    const htmlBody = await Frond.render("emails/welcome.html", {
        name: body.name,
        email: body.email,
        user_id: userId,
        base_url: process.env.APP_URL ?? "http://localhost:7148",
        app_name: "My Store",
        promo_code: "WELCOME10"
    });

    const mailer = new Messenger();
    const result = await mailer.send(body.email, `Welcome to My Store, ${body.name}!`, htmlBody);

    return res.status(201).json({ message: "Registration successful", email_sent: result.success, user_id: userId });
});
```

---

## 11. Sending Email via Queues

```typescript
import { Router, Queue, Messenger, Frond } from "tina4-nodejs";

Router.post("/api/register", async (req, res) => {
    const userId = 42;
    await Queue.produce("emails", {
        template: "emails/welcome.html",
        to: req.body.email,
        subject: `Welcome to My Store, ${req.body.name}!`,
        data: { name: req.body.name, email: req.body.email, user_id: userId, app_name: "My Store" }
    });
    return res.status(201).json({ message: "Registration successful", user_id: userId });
});

Queue.consume("emails", async (job) => {
    const { template, to, subject, data } = job.payload;
    const htmlBody = await Frond.render(template, data);
    const mailer = new Messenger();
    const result = await mailer.send(to, subject, htmlBody);
    if (!result.success) {
        console.log(`Email failed: ${result.error}`);
        return false;
    }
    return true;
});
```

---

## 12. Exercise: Build a Contact Form with Email Notification

Create `GET /contact` page, `POST /contact` endpoint that validates, sends email, and shows a flash message.

---

## 13. Solution

Create `src/routes/contact.ts`:

```typescript
import { Router, Messenger, Frond } from "tina4-nodejs";

Router.get("/contact", async (req, res) => {
    const flash = req.session._flash ?? null;
    delete req.session._flash;
    return res.html("contact.html", { flash });
});

Router.post("/contact", async (req, res) => {
    const body = req.body;
    const errors: string[] = [];
    if (!body.name) errors.push("Name is required");
    if (!body.email) errors.push("Email is required");
    if (!body.subject) errors.push("Subject is required");
    if (!body.message) errors.push("Message is required");

    if (errors.length > 0) {
        req.session._flash = { type: "error", message: `Please fill in all fields: ${errors.join(", ")}` };
        return res.redirect("/contact");
    }

    const htmlBody = await Frond.render("emails/contact-notification.html", {
        name: body.name, email: body.email, subject: body.subject,
        message: body.message, submitted_at: new Date().toLocaleString()
    });

    const mailer = new Messenger();
    const adminEmail = process.env.ADMIN_EMAIL ?? "admin@example.com";
    const result = await mailer.send(adminEmail, `Contact Form: ${body.subject}`, htmlBody, { replyTo: body.email });

    req.session._flash = result.success
        ? { type: "success", message: "Thank you for your message!" }
        : { type: "error", message: "Sorry, there was a problem sending your message." };

    return res.redirect("/contact");
});
```

---

## 14. Gotchas

### 1. Gmail Blocks "Less Secure" Apps

**Fix:** Generate an "App Password" in Google Account settings.

### 2. Emails Go to Spam

**Fix:** Use proper SPF, DKIM, DMARC records. Use a transactional email service.

### 3. HTML Email Looks Broken

**Fix:** Use inline styles. Use table-based layouts. Test across clients.

### 4. Attachment File Not Found

**Fix:** Use absolute paths. Verify the file exists before sending.

### 5. Dev Mode Silently Intercepts Emails

**Fix:** Check the dev dashboard at `/__dev`.

### 6. Template Variables Not Substituted

**Fix:** Use `Frond.render()`, not `fs.readFileSync()`.

### 7. Connection Timeout on Send

**Fix:** Test SMTP connectivity. Verify hostname, port, and encryption.
