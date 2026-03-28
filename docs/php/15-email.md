# Chapter 13: Email with Messenger

## 1. Every App Sends Email

Your SaaS app needs signup confirmations. Password resets. Weekly digest emails. Attachments, HTML templates, reliable delivery.

Email is plumbing. Every application needs it. Nobody enjoys building it. SMTP configuration. Plain text fallbacks. Attachment encoding. Connection timeouts. Bounce handling. The details stack up fast.

Tina4's `Messenger` class handles all of it. Configure via `.env`. Create an instance. Send. In development mode, emails are intercepted and shown in the dev dashboard -- no real SMTP server needed. No polluted inboxes.

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

Different purposes, different accounts. Transactional emails from one sender. Marketing from another. Override the configuration in the constructor:

```php
<?php
use Tina4\Messenger;

// Uses .env defaults
$mailer = new Messenger();

// Override specific settings
$marketingMailer = new Messenger([
    "host" => "smtp.mailgun.org",
    "port" => 587,
    "username" => "marketing@mg.yourdomain.com",
    "password" => "marketing-smtp-password",
    "encryption" => "tls",
    "from_address" => "newsletter@yourdomain.com",
    "from_name" => "My Store Newsletter"
]);
```

The constructor accepts an associative array. Override any `.env` value. Unspecified keys fall back to the `.env` configuration.

---

## 4. Sending Plain Text Email

The simplest email:

```php
<?php
use Tina4\Router;
use Tina4\Messenger;

Router::post("/api/contact", function ($request, $response) {
    $body = $request->body;

    $mailer = new Messenger();

    $result = $mailer->send(
        $body["email"],                    // To
        "Contact Form Submission",         // Subject
        "Name: " . $body["name"] . "\n" .  // Body (plain text)
        "Email: " . $body["email"] . "\n" .
        "Message:\n" . $body["message"]
    );

    if ($result["success"]) {
        return $response->json(["message" => "Email sent successfully"]);
    }

    return $response->json(["error" => "Failed to send email", "details" => $result["error"]], 500);
});
```

```bash
curl -X POST http://localhost:7146/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "message": "I love your products!"}'
```

```json
{"message":"Email sent successfully"}
```

The `send()` method returns an array with `"success"` (boolean) and `"error"` (string, present only on failure).

### The send() Method

```php
$mailer->send($to, $subject, $body, $options = []);
```

- **$to**: Recipient email address (string)
- **$subject**: Email subject line (string)
- **$body**: Email body content (string -- plain text or HTML)
- **$options**: Optional settings (array)

---

## 5. Sending HTML Email with Text Fallback

Most emails should be HTML with a plain text fallback. Some email clients do not render HTML:

```php
<?php
use Tina4\Messenger;

$mailer = new Messenger();

$htmlBody = '
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
</html>';

$textBody = "Hi Alice,\n\n" .
    "Thank you for creating your account. We are excited to have you!\n\n" .
    "Here is what you can do next:\n" .
    "- Browse our product catalog: https://mystore.com/products\n" .
    "- Set up your profile: https://mystore.com/profile\n" .
    "- Check out our current deals: https://mystore.com/deals\n\n" .
    "If you have any questions, reply to this email.\n\n" .
    "Cheers,\nThe My Store Team";

$result = $mailer->send(
    "alice@example.com",
    "Welcome to My Store!",
    $htmlBody,
    ["text_body" => $textBody]
);
```

The `text_body` option provides the plain text fallback. Email clients that cannot render HTML show the text version instead.

---

## 6. Adding Attachments

Attach files by path:

```php
<?php
use Tina4\Messenger;

$mailer = new Messenger();

$result = $mailer->send(
    "accounting@example.com",
    "Monthly Invoice #1042",
    "<h2>Invoice #1042</h2><p>Please find the invoice attached.</p>",
    [
        "attachments" => [
            "/path/to/invoices/invoice-1042.pdf",
            "/path/to/reports/monthly-summary.csv"
        ]
    ]
);
```

Each attachment is an absolute file path. Tina4 reads the file, determines the MIME type, and encodes it for transmission.

### Inline Attachments with Custom Names

```php
$result = $mailer->send(
    "alice@example.com",
    "Your Export",
    "<p>Here is your data export.</p>",
    [
        "attachments" => [
            [
                "path" => "/tmp/export-20260322.csv",
                "name" => "my-store-export.csv"  // Custom filename
            ]
        ]
    ]
);
```

The recipient sees `my-store-export.csv` regardless of the actual filename on disk.

---

## 7. CC and BCC

```php
<?php
use Tina4\Messenger;

$mailer = new Messenger();

$result = $mailer->send(
    "alice@example.com",
    "Team Meeting Notes",
    "<p>Here are the notes from today's meeting.</p>",
    [
        "cc" => ["bob@example.com", "charlie@example.com"],
        "bcc" => ["manager@example.com"],
        "reply_to" => "alice@example.com"
    ]
);
```

- **cc**: Array of email addresses to carbon copy. All recipients see CC addresses.
- **bcc**: Array of email addresses to blind carbon copy. Recipients cannot see BCC addresses.
- **reply_to**: When the recipient clicks "Reply," this address is used instead of the "From" address.

---

## 8. Reading Inbox via IMAP

Tina4's Messenger reads emails via IMAP:

```env
TINA4_MAIL_IMAP_HOST=imap.example.com
TINA4_MAIL_IMAP_PORT=993
TINA4_MAIL_IMAP_USERNAME=support@example.com
TINA4_MAIL_IMAP_PASSWORD=your-imap-password
TINA4_MAIL_IMAP_ENCRYPTION=ssl
```

```php
<?php
use Tina4\Router;
use Tina4\Messenger;

Router::get("/api/inbox", function ($request, $response) {
    $mailer = new Messenger();

    $emails = $mailer->getInbox([
        "limit" => 20,
        "unread_only" => true
    ]);

    $messages = [];
    foreach ($emails as $email) {
        $messages[] = [
            "id" => $email["id"],
            "from" => $email["from"],
            "subject" => $email["subject"],
            "date" => $email["date"],
            "preview" => substr($email["text_body"], 0, 200),
            "has_attachments" => !empty($email["attachments"])
        ];
    }

    return $response->json(["messages" => $messages, "count" => count($messages)]);
});
```

```bash
curl http://localhost:7146/api/inbox
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

```php
Router::get("/api/inbox/{id}", function ($request, $response) {
    $mailer = new Messenger();
    $emailId = $request->params["id"];

    $email = $mailer->getMessage($emailId);

    if ($email === null) {
        return $response->json(["error" => "Email not found"], 404);
    }

    return $response->json([
        "id" => $email["id"],
        "from" => $email["from"],
        "to" => $email["to"],
        "subject" => $email["subject"],
        "date" => $email["date"],
        "html_body" => $email["html_body"],
        "text_body" => $email["text_body"],
        "attachments" => array_map(fn($a) => [
            "name" => $a["name"],
            "size" => $a["size"],
            "type" => $a["type"]
        ], $email["attachments"] ?? [])
    ]);
});
```

---

## 9. Dev Mode: Email Interception

When `TINA4_DEBUG=true`, all outgoing emails are intercepted. They appear in the dev dashboard instead of reaching real recipients. No accidents during development.

Navigate to `/__dev` and find the "Mail" section. You see:

- Every email "sent" during the current session
- The To, CC, and BCC addresses
- The subject and body (HTML and plain text)
- Attachments (viewable inline)
- The timestamp

Test email without configuring a real SMTP server. Inspect the output without polluting anyone's inbox.

### Disabling Interception

To test real email delivery during development:

```env
TINA4_MAIL_INTERCEPT=false
```

Emails now reach real recipients even when `TINA4_DEBUG=true`. Use with caution. You do not want to email your entire user base from a dev machine.

---

## 10. Using Templates for Email Content

Hardcoding HTML in PHP strings is fragile and hard to maintain. Use Frond templates for email content.

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

```php
<?php
use Tina4\Router;
use Tina4\Messenger;
use Tina4\Frond;

Router::post("/api/register", function ($request, $response) {
    $body = $request->body;

    // Create user (database logic)
    $userId = 42;

    // Render the email template
    $emailData = [
        "name" => $body["name"],
        "email" => $body["email"],
        "user_id" => $userId,
        "signed_up_at" => date("F j, Y"),
        "base_url" => $_ENV["APP_URL"] ?? "http://localhost:7146",
        "app_name" => "My Store",
        "promo_code" => "WELCOME10",
        "unsubscribe_token" => bin2hex(random_bytes(16))
    ];

    $htmlBody = Frond::render("emails/welcome.html", $emailData);

    // Send the email
    $mailer = new Messenger();
    $result = $mailer->send(
        $body["email"],
        "Welcome to My Store, " . $body["name"] . "!",
        $htmlBody,
        [
            "text_body" => "Hi " . $body["name"] . ",\n\nWelcome to My Store! Your account (#" . $userId . ") has been created.\n\nCheers,\nThe My Store Team"
        ]
    );

    return $response->json([
        "message" => "Registration successful",
        "email_sent" => $result["success"],
        "user_id" => $userId
    ], 201);
});
```

```bash
curl -X POST http://localhost:7146/api/register \
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

With `TINA4_DEBUG=true`, the email appears in the dev dashboard. Inspect the rendered HTML. Check that template variables were substituted. Verify the layout.

---

## 11. Sending Email via Queues

In production, never send email inside a route handler. The SMTP handshake takes time. The user waits. Use the queue system from Chapter 11:

```php
<?php
use Tina4\Router;
use Tina4\Queue;
use Tina4\Messenger;
use Tina4\Frond;

// In the route handler, just queue the email
Router::post("/api/register", function ($request, $response) {
    $body = $request->body;
    $userId = 42; // Simulated

    Queue::produce("emails", [
        "template" => "emails/welcome.html",
        "to" => $body["email"],
        "subject" => "Welcome to My Store, " . $body["name"] . "!",
        "data" => [
            "name" => $body["name"],
            "email" => $body["email"],
            "user_id" => $userId,
            "signed_up_at" => date("F j, Y"),
            "base_url" => $_ENV["APP_URL"] ?? "http://localhost:7146",
            "app_name" => "My Store",
            "promo_code" => "WELCOME10"
        ]
    ]);

    return $response->json(["message" => "Registration successful", "user_id" => $userId], 201);
});

// The consumer sends the actual email
Queue::consume("emails", function ($job) {
    $payload = $job->payload;

    $htmlBody = Frond::render($payload["template"], $payload["data"]);

    $mailer = new Messenger();
    $result = $mailer->send(
        $payload["to"],
        $payload["subject"],
        $htmlBody
    );

    if (!$result["success"]) {
        error_log("Email failed: " . $result["error"]);
        return false; // Retry
    }

    error_log("Email sent to " . $payload["to"]);
    return true;
});
```

The route handler returns in under 50 milliseconds. The queue worker sends the email in the background. Automatic retries handle temporary SMTP failures.

---

## 12. Exercise: Build a Contact Form with Email Notification

Build a contact form that sends an email notification when submitted.

### Requirements

1. Create a `GET /contact` page that renders a contact form with fields: name, email, subject, and message

2. Create a `POST /contact` endpoint that:
   - Validates all fields are present
   - Sends an email notification to the site admin (`admin@example.com`)
   - The email should include all form fields, formatted with HTML
   - Shows a flash message on success
   - Redirects back to the contact page

3. Create an email template at `src/templates/emails/contact-notification.html` that formats the contact submission

### Test with:

```bash
# View the form
curl http://localhost:7146/contact

# Submit the form
curl -X POST http://localhost:7146/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Bob", "email": "bob@example.com", "subject": "Product inquiry", "message": "Do you ship internationally?"}'

# Check the dev dashboard for the intercepted email
# Navigate to http://localhost:7146/__dev
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

Create `src/routes/contact.php`:

```php
<?php
use Tina4\Router;
use Tina4\Messenger;
use Tina4\Frond;

Router::get("/contact", function ($request, $response) {
    $flash = $request->session["_flash"] ?? null;
    unset($request->session["_flash"]);

    return $response->render("contact.html", [
        "flash" => $flash
    ]);
});

Router::post("/contact", function ($request, $response) {
    $body = $request->body;

    // Validate
    $errors = [];
    if (empty($body["name"])) $errors[] = "Name is required";
    if (empty($body["email"])) $errors[] = "Email is required";
    if (empty($body["subject"])) $errors[] = "Subject is required";
    if (empty($body["message"])) $errors[] = "Message is required";

    if (!empty($errors)) {
        $request->session["_flash"] = [
            "type" => "error",
            "message" => "Please fill in all fields: " . implode(", ", $errors)
        ];
        return $response->redirect("/contact");
    }

    // Render the email template
    $htmlBody = Frond::render("emails/contact-notification.html", [
        "name" => $body["name"],
        "email" => $body["email"],
        "subject" => $body["subject"],
        "message" => $body["message"],
        "submitted_at" => date("F j, Y \a\\t g:i A")
    ]);

    // Send the email
    $mailer = new Messenger();
    $adminEmail = $_ENV["ADMIN_EMAIL"] ?? "admin@example.com";

    $result = $mailer->send(
        $adminEmail,
        "Contact Form: " . $body["subject"],
        $htmlBody,
        [
            "reply_to" => $body["email"],
            "text_body" => "Contact form submission from " . $body["name"] . " (" . $body["email"] . "):\n\n" .
                          "Subject: " . $body["subject"] . "\n\n" .
                          "Message:\n" . $body["message"]
        ]
    );

    if ($result["success"]) {
        $request->session["_flash"] = [
            "type" => "success",
            "message" => "Thank you for your message! We will get back to you shortly."
        ];
    } else {
        $request->session["_flash"] = [
            "type" => "error",
            "message" => "Sorry, there was a problem sending your message. Please try again later."
        ];
    }

    return $response->redirect("/contact");
});
```

**Testing:**

1. Open `http://localhost:7146/contact` in your browser
2. Fill in the form and submit
3. You should see a green "Thank you" flash message
4. Open `http://localhost:7146/__dev` to see the intercepted email
5. The email should show the sender details, subject, message, and formatted HTML

**API test:**

```bash
curl -X POST http://localhost:7146/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Bob", "email": "bob@example.com", "subject": "Product inquiry", "message": "Do you ship internationally?"}' \
  -c cookies.txt -b cookies.txt
```

The response is a `302` redirect to `/contact`. Follow the redirect to see the flash message:

```bash
curl http://localhost:7146/contact -b cookies.txt
```

The HTML response includes the success flash message.

---

## 14. Gotchas

### 1. Gmail Blocks "Less Secure" Apps

**Problem:** Sending via Gmail fails with "Authentication failed" or "Username and Password not accepted."

**Cause:** Gmail blocks SMTP access from apps that do not use OAuth2 by default. Your regular password will not work with two-factor authentication enabled.

**Fix:** Generate an "App Password" in your Google Account settings (Security > 2-Step Verification > App Passwords). Use this 16-character password as `TINA4_MAIL_SMTP_PASSWORD`. It is separate from your regular Google password.

### 2. Emails Go to Spam

**Problem:** Emails are delivered but land in the spam folder.

**Cause:** Your sending domain lacks proper DNS records (SPF, DKIM, DMARC), or you send from a free email provider (Gmail, Yahoo).

**Fix:** Use a dedicated sending domain with proper DNS records. Set up SPF, DKIM, and DMARC. Or use a transactional email service -- Mailgun, SendGrid, Amazon SES -- that manages email reputation for you.

### 3. HTML Email Looks Broken

**Problem:** The email renders in Gmail but breaks in Outlook or Apple Mail.

**Cause:** Email clients have wildly different HTML/CSS support. CSS flexbox, grid, and many modern properties do not work in email.

**Fix:** Use inline styles. Not external stylesheets, not `<style>` blocks. Use table-based layouts for complex designs. Test with an email preview tool. Keep it simple. Most transactional emails do not need elaborate designs.

### 4. Attachment File Not Found

**Problem:** `Messenger::send()` returns an error about a missing file.

**Cause:** The attachment path is relative or incorrect. The file does not exist at the specified location.

**Fix:** Use absolute paths for attachments. Verify the file exists before calling `send()`: `if (!file_exists($path)) { ... }`. If the file is generated at runtime (a PDF, for example), make sure the generation completes before sending.

### 5. Dev Mode Intercepts Emails Silently

**Problem:** You set up SMTP. No emails arrive. No errors either.

**Cause:** `TINA4_DEBUG=true` intercepts all emails and shows them in the dev dashboard. The email never reaches the SMTP server.

**Fix:** Check the dev dashboard at `/__dev` for intercepted emails. If you need real email delivery during development, set `TINA4_MAIL_INTERCEPT=false`. Remove this setting before committing.

### 6. Email Template Variables Not Substituted

**Problem:** The email body shows `{{ name }}` instead of the user's name.

**Cause:** You passed the raw template file content instead of rendering it through Frond. The template engine never ran.

**Fix:** Use `Frond::render("emails/template.html", $data)` to render the template with variables substituted. Do not use `file_get_contents()`. That gives you the raw template source.

### 7. Connection Timeout on Send

**Problem:** `Messenger::send()` hangs for 30 seconds and then fails with a timeout error.

**Cause:** The SMTP server is unreachable. The port is blocked by a firewall. The hostname is wrong.

**Fix:** Test SMTP connectivity: `telnet smtp.example.com 587`. Verify the hostname, port, and encryption settings. Check that your firewall allows outbound connections on the SMTP port. Corporate firewalls often block ports 587 and 465. Ask your network administrator.
