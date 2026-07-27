# Task: 3.13.77 batch - php#174 (security) + python#94 + php#173

## Reported
All three by justin-k-bruce (the #93 reporter), 2026-07-15/16, two against 3.13.76.

## php#174 - SECURITY: native session cookie has no HttpOnly/SameSite
Router::dispatch() starts PHP's native session (#112 fix) but called session_start()
WITHOUT session_set_cookie_params(). PHP ini defaults are cookie_httponly=0,
cookie_samesite="" -> `PHPSESSID=...; path=/` readable by any XSS + sent cross-site.
Tina4's OWN tina4_session cookie was correctly attributed 25 lines below in the SAME
method - that asymmetry was the bug. Any app keeping auth in $_SESSION was exposed.

FIX: configure the cookie before session_start() emits it, reusing TINA4_SESSION_SAMESITE
(default Lax) + the SameSite=None => Secure rule already in the file. lifetime/path/domain
carried from ini so scope is unchanged.

VERIFIED (wire contract, not params): real `php -S` + real GET + real Set-Cookie header.
  before: Set-Cookie: PHPSESSID=...; path=/
  after:  Set-Cookie: PHPSESSID=...; path=/; HttpOnly; SameSite=Lax
Negative: 3 of 4 tests FAIL with the hardening removed (4th is the not-Secure-over-HTTP
control, passes both ways by design).

PARITY: PHP-only. Python/Ruby/Node have no native-session equivalent (no session_start
anywhere) and all three already default HttpOnly=true on their own session cookie. Verified
by grep, not assumed.

## python#94 - background() runs a slow sync task concurrently with itself
asyncio.wait_for(loop.run_in_executor(...)) CANNOT cancel a started thread
(Future.cancel() returns False once running). On timeout it abandoned the wrapper, the
thread kept running, and the next tick started a SECOND copy. Every later tick piled on
another. The "was interrupted" warning was FALSE - the task was still running - which
pointed away from the cause. Reporter's app double-sent customer emails from an outbox
drainer, in ONE process, no clustering.

FIX: await the run to completion; only WARN on overrun. Extracted the loop to a
module-level `background_tick_loop` so a real test can drive the production path.
Also documents why max_workers=one-per-task is sound (no overlap).

VERIFIED: real ThreadPoolExecutor + real threads. PEAK=2 on old code, PEAK=1 after.

## Node - the SAME class of bug, found by cross-check (NOT reported)
setInterval fires on a fixed schedule and does not await an async callback -> overlap.
FIX: self-rearming setTimeout that awaits the callback (interval = gap BETWEEN runs).
Also found+fixed a latent bug: stop()/stopAllBackgroundTasks() cleared the timer but an
in-flight run would re-arm afterward. `stopped` now lives on the task object.

## php#173 - toDict() @deprecated with no replacement
The tag's TEXT was about the default $case flipping camel->snake in 3.11.22, but it sat on
the METHOD, so IDEs struck every call - and toAssoc()/toObject()/response auto-serialize
all delegate to toDict(). Removed the tag, kept the casing note as prose. Also collapsed
THREE stacked docblocks (two orphaned) into one - orphaned docblocks violate our own
PHPDoc standard from #128.

## Parity table (background overlap)
| framework | overlapped? | action |
|---|---|---|
| Python | YES (reported) | FIXED - await the run |
| Node   | YES (unreported twin) | FIXED - setTimeout re-arm |
| PHP    | no - synchronous call in the tick loop | none |
| Ruby   | no - per-task thread: sleep->call->sleep | none |

## Bugs found in MY OWN work
- [x] First Python test was THEATRE: 0.6s callback vs a 5s timeout FLOOR
      (max(interval*2, 5.0)) - it never triggered the bug and passed against the OLD code.
      Real regression test needs a >5s callback (~14s wall clock), marked `slow`.
- [x] Destroyed my own uncommitted fix with `git checkout <file>` to undo a scratch edit.
      Redid it; switched to file backups (/tmp/*_FIXED) for every negative check after.
- [x] PHP test's clean-room app called Router::dispatch($request) - it takes TWO args
      (Request, Response). Caught by the test failing, not by reading.

## Verification (re-run by me, macOS)
- PHP    3797 tests / 9529 assertions / 0 failures
- Python 3504 passed / 0 failed (3499 + 5 new background tests)
- Ruby   3887 examples / 0 failures (no code change; re-run anyway)
- Node   5372 passed / 18 failed - ALL in sessionHandlers.test (needs live
         Mongo/Redis/Valkey; Docker down here). Proven NOT mine AGAIN for this
         batch: 18 with AND without the background fix, and sessionHandlers.test
         has ZERO references to background(). CI provisions those services.
- docs:build GREEN + audit-truth --strict GREEN + audit-links OK

## Commits
- python  3a0712a fix + tests, 324ab4a release
- node    79008fd fix + test,  470ed63 release
- php     3a4b2ff8 fix (#174+#173) + test, a6a6ba2b release
- ruby    cb08b27 release only (no code change)
- docs 9a6f559 / book efbded7 / CLI f7a89f7

## Status: SHIPPED 3.13.77 (2026-07-16) - all 4 registries live; #94/#174/#173
##   commented, left open for the reporter to close
