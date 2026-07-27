# Plan: official Tina4 base images, one per language

Owner decision (2026-07-27): publish a stock Docker image per framework each release, so
deployment is `FROM ghcr.io/tina4stack/tina4-<lang>:<version>` plus the developer's own
code and nothing else. Registry: **GHCR** (no new secrets; the existing `GITHUB_TOKEN`
publishes it).

## The core principle: install the framework into the language's GLOBAL location

The image ships the language runtime AND Tina4 already installed **where that language
looks for libraries by default**. The application directory holds application code only.
A developer injects the bare minimum and runs no dependency install step.

| language | global mechanism the image must use | app dir |
|---|---|---|
| PHP | composer vendor tree resolvable via `include_path` (or a `PHP_INI` scanned dir), NOT a copy inside the app | `/app` |
| Python | `site-packages` -- `pip install tina4-python` into the image, so `import tina4_python` just works | `/app` |
| Ruby | the system `GEM_HOME` -- `gem install tina4` into the image, so `require "tina4"` just works | `/app` |
| Node | global `node_modules` / `NODE_PATH` (or `npm i -g`), so `import "tina4-nodejs"` resolves | `/app` |

**All four deploy the app to `/app`.** Same path in every language, same as every other
Tina4 convention.

## Why this matters beyond tidiness

It is what broke the PHP base image. That image copied the framework INTO the app
directory (`/app/Tina4`) while composer's generated `autoload_files.php` resolved to the
vendored layout (`$vendorDir/tina4stack/tina4php/Tina4/Constants.php`) and to
`$baseDir/src/orm/*.php`. Two layouts, one image, so `require vendor/autoload.php`
fatalled before a single line of app code ran. Copying the tree to a second location was
attempted and did NOT fix it -- the generated map references several paths that assume the
example app is the root project. Chasing them individually is whack-a-mole.

The fix is structural, not another COPY: install the framework globally, generate (or
regenerate) the autoloader for the runtime layout, and leave `/app` for app code.

## Do not confuse the two Dockerfiles

* `tina4 deploy docker` (the generator) **works for PHP, Python and Ruby**: scaffold,
  generate, build, and you get a container that boots, binds 0.0.0.0, and serves.
  It was BROKEN for Node until 2026-07-27 -- see the base-image floor below.
* The repo-root `Dockerfile` (the base image) is the broken one. It predates the
  generator, no CI has ever built it, and it carries three defects. It is NOT evidence
  that the framework cannot be containerised.

## Two traps found by actually building and booting these (2026-07-27)

**1. A base image below the framework's own floor builds clean and dies at start.**
`tina4 deploy docker` generated `FROM node:20-alpine` while tina4-nodejs declares
`engines.node >=22` and imports the built-in `node:sqlite` (added in 22.5). npm
downgrades an engines mismatch to a WARNING, so the build went green and the container
exited immediately with `ERR_UNKNOWN_BUILTIN_MODULE: No such built-in module:
node:sqlite`. Node was the only one of the four below its floor (python 3.12 vs >=3.12,
php 8.4 vs >=8.2, ruby 3.3 vs >=3.1 all clear). Fixed to `node:24-alpine` and locked by
`base_image_meets_the_framework_floor` in the CLI's `src/deploy.rs`, which is proven to
fail against `node:20`. Raising a framework's declared floor now means raising the
number in that test too.

**2. Every image size measured with `docker image inspect` is WRONG.** Under Docker
Desktop's containerd snapshotter that field returns the COMPRESSED size while reading
like a total -- 42.6 MB for a PHP image whose filesystem is 114 MB and one of whose
layers is alone 76.7 MB. `docker save` is no better; the OCI export carries compressed
blobs too. Ground truth is `du -sx /` inside the image, cross-checked against the sum of
`docker history` layer sizes (114.0 vs 115.0 MB on PHP -- they agree).

The two numbers differ by roughly 3x and mean different things, so publish BOTH:

| framework | compressed (registry pull) | on disk (unpacked) |
|---|---|---|
| PHP | 42.6 MB | 114.0 MB |
| Python | 44.5 MB | 159.5 MB |
| Ruby | 78.6 MB | 214.1 MB |
| Node | 54.4 MB | 190.2 MB |

This matters for the published "40-80MB image" claim: it holds for the COMPRESSED pull
size (PHP/Python/Node comfortably, Ruby at the ceiling) and is false for disk footprint.
Quote the claim with the word "compressed" in it, or drop it.

## Sequence

1. Rebuild each base image around the global-install principle above. Verify each boots
   and answers through a published port (that probe is also the 0.0.0.0 check: a server
   bound to 127.0.0.1 cannot answer through `docker run -p`).
2. Push the first images MANUALLY from a workstation -- `docker login ghcr.io` and
   `docker push`. This needs no CI and should not wait for it.
3. Land `.github/workflows/docker-image.yml` (already written, in all four repos) so the
   boot gate runs on every push and publishing on a tag is `needs: boot-gate`. Verified
   to FAIL against the currently-broken PHP image, so it is a real gate, not decoration.
4. Confirm PHP serves via the `stream_select` event loop under CONCURRENT load, not a
   serial accept loop. A single-request probe cannot tell the difference.
5. Point the Docker benchmark harness at the published images, so the numbers describe
   what users actually deploy.

## Status

Not done. Base images unfixed; the gate workflow is written but uncommitted. Python, Ruby
and Node base images have never been booted by anyone -- their state is unknown, not good.
