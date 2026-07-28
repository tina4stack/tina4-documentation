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
3. The gate is: **capture when no SMTP host is configured, send when one is.**
   No SMTP host means sending is impossible, so simulate it into a folder rather than
   failing - that is the "works on a laptop with no mail server" property, and it is
   the original Tina4 behaviour being deliberately restored. **`TINA4_DEBUG` does NOT
   gate sending:** debug must still be able to send real mail. An explicit
   `TINA4_MAIL_CAPTURE=true` forces capture even with SMTP configured, for anyone who
   wants the never-send-from-dev safety property. Node's third clause
   (`NODE_ENV != production` captures even with SMTP configured) is **dropped**: it
   silently eats every staging email, and forgetting one env var should not swallow
   your mail.

   > **Revision, 2026-07-28, owner decision.** This point previously read "capture when
   > `TINA4_DEBUG` is truthy OR no SMTP host is configured. Debug means never send real
   > mail, even with SMTP configured - that is the safety property worth having." The
   > owner overruled it: debug must be able to send. Tying capture to `TINA4_DEBUG`
   > would mean nobody can test a real send from a dev box, which is the common case,
   > and it silently changes behaviour for every existing `Messenger()` caller running
   > with debug on. Availability of a server, not a verbosity flag, decides whether
   > mail can be sent; wanting to suppress sending is a separate intent and gets its
   > own explicit switch. Supersedes the original point 3.

4. `capture()` becomes **internal in Ruby and Node**; it stays public but undocumented
   in **Python and PHP**. Users only ever call `send()`. This dissolves #42 rather
   than patching it: with no public positional `capture()` in the paths that had the
   bug, there is no 5th argument to mis-order. Python and PHP keep the symbol because
   they carry the most production usage (owner: "Ruby and Node can be broken easily,
   more care on Python and PHP") - there, `capture()` gains the corrected signature
   and normalisation instead of disappearing, so an existing caller keeps working and
   gets the fix.
5. `cc`/`bcc` are **normalised at the boundary** in all four (`"a@b.c"` -> `["a@b.c"]`),
   and a malformed message is corrected, never stored as a success. A dev mailbox
   exists to show you what you would have sent; accepting a broken message defeats
   its purpose (the reporter's own words on #42).
6. Both paths accept and carry `text`. The captured message must be the message.

## Blast-radius policy (owner, 2026-07-28)

Breaking changes are approved for v3 parity, but **not evenly**. The owner's ranking is
"Ruby and Node can be broken easily, more care on Python and PHP", so:

| | freedom | what that means here |
| --- | --- | --- |
| Ruby | break freely | collapse `DevMessengerProxy` away, `capture` goes private |
| Node | break freely | `createMessenger(): Messenger`, `capture` goes private, drop the `NODE_ENV` clause |
| Python | care | the `send` swap MUST go (it is the bug), but `capture()` keeps its name and gains the fix |
| PHP | care, though mostly additive | PHP has NO interception today, so adding it breaks nothing; `capture()` keeps its name |

Python and PHP therefore get the corrected behaviour without losing a public symbol.
Every framework still ends up with one signature behind one name, which is the part of
the contract that actually matters.

## Scope

- [x] Python: delete the `messenger.send = dev_send` swap; branch inside
      `Messenger.send()`. Carry `text`. Move cc/bcc normalisation into `capture()`.
      Keep `capture()` public. Gate on SMTP availability, not `TINA4_DEBUG`.
- [x] Ruby: collapse `DevMessengerProxy` into `Messenger` (one return type); branch
      inside `send`; add `text:` to `capture`; normalise cc/bcc.
- [x] PHP: add the dev branch that does not exist yet; make `capture()` internal;
      normalise cc/bcc; carry `text`.
- [x] Node: `createMessenger(): Messenger`; branch inside `send()`; `capture()`
      internal; normalise cc/bcc; add `text` to `EmailMessage`; drop the
      `NODE_ENV != production` clause.
- [x] Docs: correct `docs/nodejs/16-email.md` and `docs/python/16-email.md`.
- [ ] Changelog: `Breaking:` entry plus migration note - `capture()` stops being
      public in Node, PHP and Python; Ruby's `DevMessengerProxy` goes away; Node no
      longer captures on a non-production host that has SMTP configured.

## Tests (written first, real, positive AND negative)

Four contract points, each as a positive/negative pair - eight per framework, the
same eight in all four. Each must FAIL against today's code before the fix lands.

- [x] 1. The factory returns one type that can send.
      **+** the returned object exposes a callable `send`.
      **-** it never returns something offering `capture` but not `send` (the #41
      reproduction).
- [x] 2. `text` is the 5th positional and lands in `text`.
      **+** a captured message round-trips the plain-text alternative.
      **-** the plain-text body never appears as a `cc` recipient (the #42
      reproduction).
- [x] 3. cc/bcc are normalised at the boundary.
      **+** a proper list passes through unchanged.
      **-** a bare string is never stored as a bare string.
- [x] 4. Interception is a branch, not a swap.
      **+** the instance's `send` is the class's `send`.
      **-** `send` is not an own/instance attribute, and the dev signature is not a
      different signature.

No mocks. The dev mailbox writes to the real filesystem, so every test points
`TINA4_MAILBOX_DIR` at a temp directory and reads the JSON back off disk.

## Bugs

- [x] nodejs#41 - union factory has no common `send()`
- [x] nodejs#42 - `capture()` files the text body as `cc`, unvalidated
- [x] (new, unreported) Python has #42 too, via the instance-method swap, and
      `send(text=...)` raises `TypeError` on a dev messenger
- [x] (new, unreported) PHP's factory has no dev interception at all
- [x] (new, unreported) Ruby's factory also returns a union
- [x] (new, unreported) the dev-capture gate differs four ways
- [x] (new, unreported) all four drop `text` on the dev path
- [x] (new, unreported) two doc pages promise a drop-in that no framework honours

## Commits

- `9075423`  Python - swap deleted, branch inside send(), capture carries text + normalises
- `721aba94` PHP - dev branch added where none existed, capture aligned with send
- `c96ba9f`  Node - union factory collapsed (#41), capture aligned (#42), NODE_ENV clause dropped
- `33b25de`  Ruby - DevMessengerProxy deleted, text carried, cold-reachable factory

## Found during implementation, not in the original evidence

- **Ruby's `Tina4.create_messenger` was unreachable on a cold require.** `autoload`
  fires only on a CONSTANT reference and a module function is not a constant, so
  `require "tina4"; Tina4.create_messenger` raised `NoMethodError` unless something
  else had already touched `Tina4::Messenger`. Verified against the prior commit, so
  pre-existing. Fixed by moving the implementation onto the class and adding an eager
  module-level delegator.
- **PHP's type system turned the capture realignment into a hard error**, which is the
  best possible outcome: four existing tests were passing a cc ARRAY into the new
  `?string $text` and failed instantly. Those were exactly the callers the
  realignment targets.
- **Node's own tests contained the #42 bug.** One `capture()` call passed NINE
  arguments against the ten-parameter order, silently shifting `from` off the end.
- **Three frameworks confer escaping safety from a value the filter produces**
  (SafeString in Python/Ruby, RAW_MARKER in PHP); only Node trusted a name. Unrelated
  to the messenger, found in the same sweep, fixed separately.

## Status: SHIPPED to v3 in all four. Not released (owner: no releases yet).
