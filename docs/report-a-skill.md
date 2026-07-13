---
title: Report a Stale or Incorrect Skill
description: How to report a Tina4 AI skill that no longer matches the framework, so it gets fixed for everyone.
---

# Report a Stale or Incorrect Skill

Tina4 ships AI skills so Claude, Cursor, Copilot, and other assistants write
idiomatic Tina4 code out of the box. There are three: `tina4-developer` (build
apps), `tina4-js` (the reactive frontend), and `tina4-maintainer` (work on the
framework itself). Install them with the
[skills installer](/get-started#skills-make-your-ai-assistant-fluent-in-tina4).

A skill is documentation, and documentation drifts. A method gets renamed, a
default flips, a column changes name, and the skill keeps describing the old
behavior. When that happens the assistant confidently writes code against an API
that no longer exists. That is the bug we want to hear about.

## When to report

Report a skill when its guidance contradicts what the framework actually does:

- A method, class, decorator, or env var the skill names does not exist in the code.
- The skill describes one behavior and the code does another (a wrong default, a
  renamed field, a changed return shape).
- An example the skill gives fails to run against the current release.

The code is the source of truth. A skill that disagrees with it is wrong, every time.

## How to report

Open a skill report. It takes a minute and it routes straight to the people who
maintain the skills:

- **File on GitHub:** [open a skill report](https://github.com/tina4stack/tina4-documentation/issues/new?labels=skill&template=skill-report.yml)

Give us enough to reproduce and fix it in one pass:

1. **Which skill** it is: `tina4-developer`, `tina4-js`, or `tina4-maintainer`.
2. **Where** it says the wrong thing: the section heading, and the reference file
   if you know it (for example `references/data-and-orm.md`).
3. **What the skill claims**, quoted.
4. **What the code actually does**: a `file:line` in the framework source, or a
   short snippet that behaves differently from the skill's description.
5. **Framework and version** you checked against (for example `tina4-python 3.13.55`).

## Working with an AI assistant

If your assistant is following a Tina4 skill and hits guidance that fights the real
framework, it should stop and tell you rather than paper over the gap. Ask it to
show you exactly what the skill claims and what the code does. Once you agree the
skill is wrong, file the report with the details it gathered. The assistant should
never open the issue on its own; the report goes out with your say-so.

## What happens next

Every skill report lands as a `skill` issue on the documentation repository. The
maintainers fix the canonical skill in `tina4-python`, propagate the identical fix
to the other frameworks, and ship it with the next release. Re-run the installer to
pick up the corrected skill.

The fewer surprises the skills hold, the less code you write twice.
