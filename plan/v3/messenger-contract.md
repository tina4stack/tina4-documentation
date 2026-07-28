# Task: one messenger contract across all four frameworks

Raised by `tina4stack/tina4-nodejs#41` and `#42`. Both are symptoms; the disease is
that one subsystem has four different shapes.

## The evidence

Signatures read from source on 2026-07-28 and verified by running the code, not
recalled. An earlier draft of this table got Python wrong in Python's favour; the
corrected version is below, with the proof.

| | factory returns | dev-capture gate | `send()` 5th positional | dev path carries `text` | cc/bcc normalised |
| --- | --- | --- | --- | --- | --- |
| Python | `Messenger`, with `send` **swapped on the instance** | `TINA4_DEBUG` | class: `text`. **swapped instance: `cc`** | **no** - `dev_send` has no `text` parameter at all | in `dev_send` yes, in `capture()` no |
| Ruby | `Messenger` **or** `DevMessengerProxy` (a union) | `TINA4_DEBUG` AND no SMTP host | n/a - keywords on both | no | no |
| PHP | `static` (one type) | **never - there is no interception** | `text` | n/a - the factory never captures | no |
| Node | `Messenger` **or** `DevMailbox` (a union) | `TINA4_DEBUG` OR no SMTP OR `NODE_ENV != production` | `text` | no | no |

Read that middle column again: the gate that decides whether a dev box sends real
email has four different answers, and one of them is "always send".

### Python is not the reference here, and this is the proof

`create_messenger()` installs the dev path with `messenger.send = dev_send`, and
`dev_send` is declared `(to, subject, body, html=False, cc=None, ...)`. The class
declares `(to, subject, body, html=False, text=None, cc=None, ...)`. Two different
signatures behind one name. Run against 3.13.92 with `TINA4_DEBUG=true`:

```
class send   : (self, to, subject, body, html=False, text=None, cc=None, ...)
instance send: (to, subject, body, html=False, cc=None, ...)
is class send? False
kwarg text   : TypeError -> dev_send() got an unexpected keyword argument 'text'
positional   : {'success': True, ...}      <- reported success
captured cc  : ['plain text alternative']  <- the plain-text body, filed as a recipient
has 'text'?  : False
```

So the documented, correct call `send(to, subject, body, True, "plain text")` files
the plain-text body as a **CC recipient** in Python too, and the keyword form does
not merely mis-order - it raises `TypeError`. #42 is a Python bug as much as a Node
one, and Python's version is worse: Node at least keeps one signature.

## The defects

- **#41, Node only.** `createMessenger(): Messenger | DevMailbox` and those two share
  no sending method, so the documented call throws `TypeError` whenever the dev
  mailbox branch is taken. Ruby also returns a union, but both arms expose `send`,
  so Ruby escapes the crash by luck of naming rather than by design.
- **#42, all four.** `send()`'s 5th positional is `text`, `capture()`'s is `cc`. Node
  and PHP diverge at `capture()`; Python diverges at `send()` itself via the swap
  (proof above). Ruby escapes only because Ruby has real keyword arguments.
- **PHP never captures.** `Messenger::createMessenger()` is `return new static()`.
  On a dev box with no SMTP host, PHP opens a socket to `localhost:587` and fails.
  The DevMailbox class exists and is unreachable from the factory.
- **All four drop `text` on the dev path.** No `capture()` in any framework has a
  `text` parameter, so what you inspect in the mailbox is not what would have been
  sent. A dev mailbox that shows you a different message than the one you wrote is
  worse than no mailbox.
- **Documentation defect, a First Principle violation.** `docs/nodejs/16-email.md:504`
  and `docs/python/16-email.md:488` both tell the reader to "use `createMessenger()`
  instead of `new Messenger()`". That promises a drop-in neither framework delivers.

## Ranking, per ADR-0004 (best implementation prevails, parity flows both ways)

No framework is the master here. Each one holds exactly one piece:

- **Python has the best `cc`/`bcc` handling** - `dev_send` normalises a bare string
  to a list. Keep the behaviour, move it to the boundary so `capture()` gets it too.
- **Ruby has the best signature discipline** - native keyword arguments make the #42
  class of bug unrepresentable rather than merely absent. It is also the only
  framework whose two factory arms agree on a method name.
- **PHP has the best factory type** - one concrete return, no union. It is also the
  only one with no dev path at all, so it gains the most.
- **Node has the best gate, in part** - "`TINA4_DEBUG` OR no SMTP configured" is the
  right pair of conditions. Its third clause is a footgun (below).

This is the case ADR-0004 was written for: "Python is master" would have shipped the
worst mechanism and a live #42 to three other languages.

## The canonical contract

1. The factory returns **one concrete type** in every framework. Never a union.
2. Interception is a **real branch inside `send()`**, never a runtime method swap. One
   name, one signature, one place to read. If a dev mailbox is active, `send()`
   captures and returns the same result shape a real send returns.
3. The gate is: **capture when `TINA4_DEBUG` is truthy OR no SMTP host is configured.**
   Debug means never send real mail, even with SMTP configured - that is the safety
   property worth having. No SMTP host means sending is impossible, so capture
   instead of failing. Node's third clause (`NODE_ENV != production` captures even
   with SMTP configured and debug off) is **dropped**: it silently eats every
   staging email, and forgetting one env var should not swallow your mail.
4. `capture()` becomes **internal**. Users only ever call `send()`. This dissolves #42
   rather than patching it: with no public positional `capture()`, there is no 5th
   argument to mis-order.
5. `cc`/`bcc` are **normalised at the boundary** in all four (`"a@b.c"` -> `["a@b.c"]`),
   and a malformed message is corrected, never stored as a success. A dev mailbox
   exists to show you what you would have sent; accepting a broken message defeats
   its purpose (the reporter's own words on #42).
6. Both paths accept and carry `text`. The captured message must be the message.

## Scope

- [ ] Python: delete the `messenger.send = dev_send` swap; branch inside
      `Messenger.send()`. Carry `text`. Move cc/bcc normalisation into `capture()`.
- [ ] Ruby: collapse `DevMessengerProxy` into `Messenger` (one return type); branch
      inside `send`; add `text:` to `capture`; normalise cc/bcc.
- [ ] PHP: add the dev branch that does not exist yet; make `capture()` internal;
      normalise cc/bcc; carry `text`.
- [ ] Node: `createMessenger(): Messenger`; branch inside `send()`; `capture()`
      internal; normalise cc/bcc; add `text` to `EmailMessage`; drop the
      `NODE_ENV != production` clause.
- [ ] Docs: correct `docs/nodejs/16-email.md` and `docs/python/16-email.md`.
- [ ] Changelog: `Breaking:` entry plus migration note - `capture()` stops being
      public in Node, PHP and Python; Ruby's `DevMessengerProxy` goes away; Node no
      longer captures on a non-production host that has SMTP configured.

## Tests (written first, real, positive AND negative)

Four contract points, each as a positive/negative pair - eight per framework, the
same eight in all four. Each must FAIL against today's code before the fix lands.

- [ ] 1. The factory returns one type that can send.
      **+** the returned object exposes a callable `send`.
      **-** it never returns something offering `capture` but not `send` (the #41
      reproduction).
- [ ] 2. `text` is the 5th positional and lands in `text`.
      **+** a captured message round-trips the plain-text alternative.
      **-** the plain-text body never appears as a `cc` recipient (the #42
      reproduction).
- [ ] 3. cc/bcc are normalised at the boundary.
      **+** a proper list passes through unchanged.
      **-** a bare string is never stored as a bare string.
- [ ] 4. Interception is a branch, not a swap.
      **+** the instance's `send` is the class's `send`.
      **-** `send` is not an own/instance attribute, and the dev signature is not a
      different signature.

No mocks. The dev mailbox writes to the real filesystem, so every test points
`TINA4_MAILBOX_DIR` at a temp directory and reads the JSON back off disk.

## Bugs

- [ ] nodejs#41 - union factory has no common `send()`
- [ ] nodejs#42 - `capture()` files the text body as `cc`, unvalidated
- [ ] (new, unreported) Python has #42 too, via the instance-method swap, and
      `send(text=...)` raises `TypeError` on a dev messenger
- [ ] (new, unreported) PHP's factory has no dev interception at all
- [ ] (new, unreported) Ruby's factory also returns a union
- [ ] (new, unreported) the dev-capture gate differs four ways
- [ ] (new, unreported) all four drop `text` on the dev path
- [ ] (new, unreported) two doc pages promise a drop-in that no framework honours

## Commits

- (hash  description - one line per landed change, per framework)

## Status: Tests being written. No implementation yet.
