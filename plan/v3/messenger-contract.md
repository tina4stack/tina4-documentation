# Task: one messenger contract across all four frameworks

Raised by `tina4stack/tina4-nodejs#41` and `#42`. Both are symptoms; the disease is
that one subsystem has four different shapes.

## The evidence

Signatures read from source on 2026-07-28, not from memory.

| | dev-mailbox call | 5th positional arg | `text` in dev path | factory returns | cc/bcc normalised |
| --- | --- | --- | --- | --- | --- |
| Python | `capture(to=, subject=, ...)` via kwargs | n/a (kwargs) | no | `Messenger` (one type) | **yes** |
| Ruby | `capture(to:, subject:, ...)` kwargs | n/a (kwargs) | no | `create_messenger(**options)` | not checked |
| PHP | `capture()` positional | **`array $cc`** | no | `static` (one type) | no |
| Node | `capture()` positional | **`cc: string[]`** | no | **`Messenger \| DevMailbox`** | no |

Against `Messenger.send()`, whose 5th positional argument is `text` in all four.

Two defects fall out:

- **#41, Node only.** `createMessenger(): Messenger | DevMailbox` and the two share
  no sending method, so the documented call throws `TypeError` whenever SMTP is not
  configured. PHP and Python return a single type; only Node unions.
- **#42, Node and PHP.** `send()`'s 5th argument is `text`, `capture()`'s is `cc`, so
  moving a working call across silently files the plain-text body as a CC recipient
  and reports success. Ruby and Python escape it only because they pass keywords.

And a documentation defect, which is a First Principle violation:
`docs/nodejs/16-email.md:504` and `docs/python/16-email.md:488` both instruct the
reader to "use `createMessenger()` instead of `new Messenger()`". That promises a
drop-in the Node code does not deliver.

## Ranking, per ADR-0004 (best implementation prevails, parity flows both ways)

**Python has the best behaviour.** `create_messenger()` returns one type; the dev
path calls `capture()` with keyword arguments; and it normalises `cc`/`bcc` from a
bare string to a list on the way in. That is all three fixes, already shipped.

**Python has the worst mechanism.** It achieves this by assigning over the instance
method: `messenger.send = dev_send`. That leaves the class's `send` and the object's
`send` as different callables, cannot be expressed idiomatically in PHP or
TypeScript, and hides the interception from anyone reading the class.

**Ruby has the best signature discipline** - native keyword arguments make the #42
class of bug unrepresentable rather than merely absent.

So parity flows FROM Python's semantics, NOT from its implementation, and Node is
the framework that changes most. This is the case ADR-0004 was written for: the
master is not automatically right, and an audit ranks quality.

## The canonical contract

1. The factory returns **one concrete type** in every framework. Never a union.
2. Interception is a **real branch inside `send()`**, not a runtime method swap. If a
   dev mailbox is configured, `send()` captures and returns the same result shape it
   would have returned after a real send.
3. `capture()` becomes **internal**. Users only ever call `send()`. This dissolves
   #42 rather than patching it: with no public positional `capture()`, there is no
   5th argument to mis-order.
4. `cc`/`bcc` are **normalised at the boundary** in all four (`"a@b.c"` -> `["a@b.c"]`),
   and a malformed message is corrected or rejected, never stored as a success. A dev
   mailbox exists to show you what you would have sent; accepting a broken message
   defeats its purpose (the reporter's own words on #42).
5. Both paths accept `text`. The dev mailbox currently drops it in all four, so the
   captured message is not what would have been sent.

## Scope

- [ ] Python: replace the `messenger.send = dev_send` swap with a real branch in
      `Messenger.send()`; keep the existing semantics, which are correct. Add `text`.
- [ ] Ruby: confirm `create_messenger` returns one type; add `text:` to `capture`.
- [ ] PHP: single-type factory already correct. Make `capture()` internal, normalise
      cc/bcc, add `text`.
- [ ] Node: adopt the whole contract. `createMessenger(): Messenger`, interception
      inside `send()`, `capture()` internal, normalise cc/bcc, add `text`.
- [ ] Docs: correct `docs/nodejs/16-email.md` and `docs/python/16-email.md`.
- [ ] Changelog: `Breaking:` entry plus migration note - `capture()` stops being
      public in Node, PHP and Python.

## Tests (written first, real, positive AND negative)

Each must FAIL against today's code before the fix lands, in all four:

- [ ] `createMessenger()` returns a type exposing `send()`, with SMTP unconfigured
      (the exact #41 reproduction).
- [ ] `send(to, subject, body, true, "plain text")` with no SMTP: the captured
      message has the text in its text field and `cc` EMPTY (the exact #42
      reproduction).
- [ ] `cc` passed as a bare string arrives as a one-element list.
- [ ] A captured message round-trips `text`.

No mocks. The dev mailbox writes to the real filesystem, so these read the file back.

## Bugs

- [ ] nodejs#41 - union factory has no common send()
- [ ] nodejs#42 - capture() files the text body as cc, unvalidated
- [ ] (new, unreported) PHP has #42's divergence too
- [ ] (new, unreported) all four drop `text` on the dev path
- [ ] (new, unreported) two doc pages promise a drop-in that Node does not honour

## Commits

- (hash  description - one line per landed change, per framework)

## Status: Planned. Nothing implemented.
