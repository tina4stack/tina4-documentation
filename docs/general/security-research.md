# Security research policy

This page is for security researchers who find a flaw in Tina4. It follows your report from the day it lands to the day the fix is public. It also sets out the rules you can count on while you work. It is built on ISO/IEC 29147 for disclosure and ISO/IEC 30111 for handling.

## What's in scope

- **In scope:** the code in `tina4stack/tina4` (the command-line tool), `tina4-python`, `tina4-php`, `tina4-ruby`, `tina4-nodejs`, `tina4-js` and `tina4-documentation`, the packages published from them, the release artefacts built from them, and the installer scripts served from tina4.com.
- **Out of scope:** applications built with Tina4 - report those to their owners. Also out of scope are features that only exist in development mode (`TINA4_DEBUG=true`), when the report depends on exposing a development server to an untrusted network. A report that shows a development feature can be reached from a normal production setup is in scope.

## How to report

1. **Preferred:** open the repository's **Security** tab and choose **Report a vulnerability**. GitHub will create a private advisory that only you and the maintainers can see.
2. **Email:** info@tina4.com, with `SECURITY` in the subject line.

Please include:

- the affected package and version, or the commit
- the language and database engine, where it matters
- the steps to reproduce, or a proof of concept
- the impact you believe it has

Please don't open a public issue, pull request or discussion about it.

## What happens next

When your report lands, we'll confirm we have it, try it for ourselves and score it. If it's real, we'll fix it in every framework it touches. A flaw in one language is checked in all four, and the fixes ship together.

| Step | Target |
|---|---|
| Acknowledge your report | 3 business days |
| Triage and severity, scored with the Common Vulnerability Scoring System (CVSS) v3.1 | 10 business days |
| Fix released: Critical or High | 30 days from triage |
| Fix released: Medium or Low | next scheduled release, at most 90 days |
| Public advisory, with a Common Vulnerabilities and Exposures (CVE) identifier where one applies | when the fix ships |

- **Coordinated disclosure.** We'll agree a date with you to go public, 90 days by default. If a fix will take longer, we'll tell you why and agree a new date. We won't let it slide quietly.
- **Advisories and CVEs.** The advisory is published through GitHub Security Advisories, which also requests the CVE.
- **Credit.** You'll be named in the advisory unless you ask us not to be.
- **No bug bounty.** Tina4 doesn't pay for reports. The credit is the reward we can offer, and it's given freely.

## Rules of engagement

- **Test against your own copy.** Run Tina4 on a machine or instance you control. Don't test against anybody else's site, including tina4.com, beyond reading its public pages.
- **Don't touch other people's data.** If your research reaches data that isn't yours, stop, don't keep a copy, and tell us in your report.
- **No denial of service.** Don't run load, flood or resource exhaustion tests against a service you don't own. A proof of concept on your own instance is fine.
- **No social engineering and no physical attacks** against Code Infinity, its staff or its users.
- **Keep it private until the agreed date.**

## Safe harbour

If you work in good faith and follow this policy, Code Infinity will treat your research as authorised. We won't take legal action against you, and we won't ask anybody else to. If somebody else does, we'll say in public that your work kept to this policy. This covers your own copy of Tina4 and the reports you send us. It can't give you leave to test systems that belong to somebody else.

If you're not sure a plan is covered, ask us first at info@tina4.com. We'd rather answer a question than read about it later.

Each repository's `SECURITY.md` carries the short version of this page...
