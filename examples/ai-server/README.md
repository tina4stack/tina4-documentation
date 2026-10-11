# Tina4 local AI server

A local model server you run yourself, served by Tina4 - no FastAPI, no Flask.
Tina4 handles the HTTP; the tokens come from a model engine vendored under `lib/`,
so the server clones nothing. On Apple Silicon it runs through MLX on the Metal
GPU, on an NVIDIA box through the CUDA build of torch, and on anything else through
CPU torch. One model answers both text and images.

## Run it

```bash
./setup.sh
```

That is the whole thing. The script installs the dependencies, downloads the model
once, and then starts the server on http://127.0.0.1:11437. First run fetches the
weights; every run after that is instant. On Windows, run `.\setup.ps1`.

You need the `tina4` client on your PATH (https://tina4.com/cli) and Python 3.12.

Override anything up front:

```bash
AI_SERVER_PORT=7788 ./setup.sh                      # a different port
HARNESS_CUDA=cpu ./setup.sh                          # force CPU even with a GPU
```

## Routes

| Method | Path | Body | Reply |
|---|---|---|---|
| GET  | `/health`   | - | `ok` |
| GET  | `/info`     | - | `{repo_id, backend, device}` |
| GET  | `/memory`   | - | model memory figures in GB |
| POST | `/generate` | `{messages, max_tokens?, temperature?, enable_thinking?}` | `{text}` |
| POST | `/describe` | `{image, prompt?, max_tokens?}` (image is a local path) | `{text}` |

```bash
curl -s localhost:11437/generate -H 'content-type: application/json' \
  -d '{"messages":[{"role":"user","content":"Say hello."}],"max_tokens":32}'
```

## Point Tina4 at it

A Tina4 app's dev-admin reads three environment variables. Set them in your app's
`.env` and the dashboard assistant talks to this server:

```bash
TINA4_AI_PROVIDER=local
TINA4_AI_URL=http://localhost:11437/generate
TINA4_AI_MODEL=qwen38-2b-distill-4bit
```

The paths and the shapes match the harness model server exactly, so anything
already pointed at the harness keeps working when it is pointed here instead.
