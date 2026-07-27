# Plan: production Docker benchmark harness

## Goal

Replace the bare-metal, dev-server benchmark with a containerised, production-mode
comparison at pinned latest versions, because that is how Tina4 is deployed and it is the
only comparison that means anything.

## Why the current numbers get retired, not refreshed

`benchmarks/benchmark.py` starts each competitor on its **development** server and Tina4
on its **built-in production** server, then compares throughput:

| framework | what the old harness ran | what that is |
|---|---|---|
| Tina4 PHP | built-in `stream_select` server | production |
| Laravel | `artisan serve` | dev only, explicitly not for production |
| Symfony / CodeIgniter | `php -S` | PHP's single-threaded dev server |
| Django | `runserver` | dev only, Django's own docs say never in production |
| Ruby / Sinatra | `WEBrick` | dev only |

That is not a framework comparison, it is a comparison of one production server against
five dev servers, and it is where "110x faster than Laravel" came from. Owner's call
(2026-07-27): the dev-runtime comparison is not important. So section 1 of each
BENCHMARK.md gets **removed and replaced** by the Docker results below rather than
re-measured. Re-measuring would only make a meaningless number look precise.

## Design

One container per framework, measured one at a time.

- **Production mode, always.** Tina4 via its own `tina4 deploy docker` generator (the real
  deploy path, so this dogfoods it). No dev server anywhere, on either side.

- **DO NOT hand-write Dockerfiles for the competitors** (owner's call, 2026-07-27). Use the
  best OFFICIAL or COMMUNITY image for each, and **state the source and tag in the results**
  next to the number. Reason: a benchmark where we author the opponent's container is one
  nobody should trust, and the obvious rebuttal to any result we publish is "you configured
  it badly". Using their own published image removes that argument entirely, and is less
  work besides.

  Where no canonical image exists -- Django, Flask and Sinatra have no official Docker Hub
  image -- pick the most widely used community image, name it explicitly with its tag, and
  say why it was chosen. If nothing defensible exists for a framework, record it as
  NOT MEASURED rather than quietly rolling our own; an unmeasured row is honest, a
  self-built opponent is not.
- **Pinned latest versions**, recorded in the result JSON. A benchmark whose versions are
  not recorded cannot be reproduced or re-run later.
- **Identical resource limits** on every container: `--cpus=2 --memory=1g`. Without this,
  a framework that spawns more workers wins on core count rather than efficiency. The host
  has 8 CPUs and 3.8 GB available to Docker, so 2/1g leaves ample headroom for the load
  generator.
- **Same two endpoints as the existing contract**, so results stay comparable to history:
  `/api/bench/json` and `/api/bench/list` (100 items). For a STOCK scaffold with no bench
  routes, probe `/health` -- a built-in in all four frameworks returning the same JSON
  shape, so it is genuinely like-for-like.

  **Never probe `/` on a stock scaffold.** A fresh Python, Ruby or Node scaffold has an
  empty `src/routes/` and answers 404 there (PHP ships a home page, which is what made
  the wrong assumption look right). `curl -fsS` scores a 404 as a failure, so a first run
  of this harness recorded three perfectly healthy containers as "did not survive 1g".
  The tell was `oom_killed=false` at a 1 GB limit: nothing had been killed, so nothing
  had run out of memory, so the probe -- not the container -- was what failed. A
  measurement that reports a failure the mechanism cannot explain is reporting its own
  bug; chase the contradiction before writing the number down.
- **Load generated from the host** with `hey`, identical `-n`/`-c` for every target.
- **Strictly serial.** One container up and measured at a time. Two at once contend for
  CPU and both numbers are wrong; that is the leading suspect for how the published
  figures drifted from reality in the first place.
- **Image size, minimum viable memory, and survival at a shared ceiling** recorded per
  framework. See the four measurements below: these matter more than throughput for
  anyone sizing a deployment, and none of them has ever been published here.

## The four things measured per framework

Throughput alone is the least interesting of these for someone choosing a deployment.

1. **Image size, BOTH numbers.** Compressed (what you pull from a registry: bandwidth and
   deploy time) and on-disk unpacked (what the node actually stores). They differ by
   about 3x, so quoting one alone misleads whichever way you pick.

   **Do NOT measure with `docker image inspect -f '{{.Size}}'`.** Under Docker Desktop's
   containerd snapshotter it returns the COMPRESSED size while reading like a total: it
   reported 42.6 MB for a PHP image whose filesystem is 114 MB and one of whose layers is
   alone 76.7 MB. `docker save` has the same flaw -- the OCI export carries compressed
   blobs. Ground truth is `du -sx /` inside the image, cross-checked against the sum of
   `docker history` layer sizes; the two agree to within 1 MB. Every size measured with
   inspect before 2026-07-27 is void, including the 40.7 MB once quoted for PHP.

   This decides how the "40-80MB image" claim may be written: it is true of the
   COMPRESSED pull size and false of the disk footprint (114-214 MB). Say "compressed"
   or do not make the claim.

2. **Minimum viable memory.** Step the container's `--memory` limit DOWN a ladder
   (1g, 512m, 256m, 192m, 128m, 96m, 64m) and record the lowest rung where the framework
   still **boots and serves N consecutive successful requests**. Booting is not enough: a
   container that starts and then OOMs under load has not passed. This is the number that
   decides what instance size you can actually deploy on, and nobody has ever published it.

3. **Survival at a common ceiling.** Give every framework the SAME tight limit (256m, then
   128m) and record who survives and who is OOM-killed. Owner's framing: "use the same and
   see which framework survives". This is a pass/fail table, and a pass/fail table is
   harder to spin than a throughput chart. If Tina4 dies where Express lives, that ships.

4. **Throughput** at the shared `--cpus=2 --memory=1g` baseline, for continuity with the
   existing json/list contract.

Recorded per framework alongside the versions, so a future run can be compared to this one.

## Scope order (vertical slice first)

1. **PHP slice**: Tina4 PHP, Slim, Laravel. Prove the harness end to end, including the
   fairness controls, before scaling. If the harness is wrong, it is wrong cheaply.
2. Python: Tina4, FastAPI, Flask, Django, Starlette.
3. Ruby: Tina4, Sinatra, Roda, Rails.
4. Node: Tina4, Express, Koa, Fastify.
5. Rewrite section 1 in all four BENCHMARK.md files from the measured JSON, with the
   provenance line (date, machine, versions, limits, tool) the size tables now carry.

## Non-goals

- Not tuning any framework for the benchmark. Documented production defaults only, ours
  included. A hand-tuned Tina4 against stock competitors is the same dishonesty as a
  production Tina4 against dev-server competitors.
- Not chasing a win. If Tina4 loses on equal footing, that is the number that ships, and
  the improvement work starts from there.

## Status

In progress. Bare-metal dev-server runs stopped mid-flight and deliberately discarded
(2026-07-27).
