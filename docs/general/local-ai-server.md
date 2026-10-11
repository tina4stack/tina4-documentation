# A local AI server, run by you

Tina4's developer tools can lean on a Large Language Model (LLM) - the dashboard
assistant, the plan generator, the code help. The model does not have to live in
someone else's data centre. You can run it on your own machine, and Tina4 will
serve it itself.

This page sets up that server. It is a small Tina4 app: no FastAPI, no Flask, no
hosted key. Tina4 answers the HTTP, and the tokens come from a model engine
vendored into the example, so the server clones nothing. The engine picks itself
for the machine - MLX on the Metal Graphics Processing Unit (GPU) on Apple Silicon,
the CUDA build of torch on an NVIDIA box, CPU torch everywhere else - and one model
handles both text and images.

The example lives in the documentation, at `examples/ai-server/`.

## Run it

One line fetches the server from tina4.com and starts it:

```bash
curl -fsSL https://tina4.com/ai-server.sh | sh
```

That downloads the self-contained server into `~/.tina4/ai-server`, installs the
dependencies, downloads the model once, and starts it on http://127.0.0.1:11437.

If you have the documentation checked out, you can run the same bundle straight
from the repository instead:

```bash
cd examples/ai-server
./setup.sh
```

Either way it is the whole thing. On Windows, run `examples\ai-server\setup.ps1`.
First run fetches the weights; every run after that starts straight away.

You will need two things on your machine first: the `tina4` client on your PATH
(see the [CLI reference](cli.html)) and Python 3.12.

Trace what the script does, in order. It will build a virtual environment and
install the model engine the markers choose for your hardware - the engine code
itself is already here, vendored under `lib/`. It will then download the model -
and here it is careful:
if a local 4-bit folder already holds the weights it is left alone, and only when
that folder is absent does it fetch the weights from Hugging Face, so it never
pulls a second, heavier copy over one already on disk. First run fetches once;
every run after that starts straight away. Finally it hands off to `tina4 serve`,
which turns the server on.

Override anything up front:

```bash
AI_SERVER_PORT=7788 ./setup.sh                      # a different port
HARNESS_CUDA=cpu ./setup.sh                          # force CPU even with a GPU
```

## What it serves

| Method | Path | Body | Reply |
|---|---|---|---|
| GET  | `/health`   | - | `ok` |
| GET  | `/info`     | - | `{repo_id, backend, device}` |
| GET  | `/memory`   | - | model memory figures in gigabytes |
| POST | `/generate` | `{messages, max_tokens?, temperature?, enable_thinking?}` | `{text}` |
| POST | `/describe` | `{image, prompt?, max_tokens?}`, where `image` is a local path | `{text}` |

The routes are public - `noauth` - because this is a server you run on your own
machine for your own tools, and there is no login to get in the way. It boots as a
plain server, not in debug, so it carries no dashboard of its own, and Tina4's
built-in engine answers every request rather than any production server a model
dependency may have pulled in.

A request to `/generate` carries a chat transcript. It is handed to the model on a
worker thread, so the one request that is thinking never freezes the next, and a
lock lets two requests queue rather than collide on a model that can only think one
thought at a time. The reply comes back as `{text}`.

```bash
curl -s localhost:11437/generate -H 'content-type: application/json' \
  -d '{"messages":[{"role":"user","content":"Say hello."}],"max_tokens":32}'
```

`/describe` is the same idea with eyes: give it the path to an image and a
question, and the model reads the picture and answers.

## Point Tina4 at it

A Tina4 app's dev-admin reads three environment variables. Set them in the app's
`.env`, and the dashboard assistant will talk to this server instead of a hosted
one:

```bash
TINA4_AI_PROVIDER=local
TINA4_AI_URL=http://localhost:11437/generate
TINA4_AI_MODEL=qwen38-2b-distill-4bit
```

`local` needs no key. The paths and the request shapes match the harness model
server exactly, so anything already pointed at the harness keeps working the moment
it is pointed here.

That is the local loop closed: the model on your machine, the server Tina4's own.
Start it, set the three variables, and open your dashboard.
