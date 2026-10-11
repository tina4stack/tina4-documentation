# Vendored model engine

These files are a snapshot of the model-serving core from the tina4-harness
project - the model loader, the MLX and torch backends, and the model downloader.
They are vendored here on purpose: the AI server is self-contained and clones
nothing at install time.

| File | What it does |
|---|---|
| `model.py` | picks a backend for the machine and loads the model |
| `download.py` | fetches the weights into `models/` once, then reuses them |
| `backends/mlx_backend.py` | Apple Silicon, Metal GPU, via mlx-vlm |
| `backends/torch_backend.py` | CUDA or CPU, via torch + transformers |
| `backends/remote_backend.py` | a thin proxy to a model server already running |

## Tina4 additions (on top of the snapshot)

- `generate(..., raw_prompt=str)` on the MLX and torch backends (and the
  `HarnessModel` interface): sends the prompt UNTEMPLATED, for fill-in-the-middle
  and exact-prompt completion. Keep this when re-syncing from source.

## Refresh

These are a copy, so they can drift. To re-sync from a known-good source, replace
the files in this folder with the matching ones and keep the package name
`ai_engine` (the modules use relative imports, so only the top folder name
matters). Do not edit them here by hand - change them at the source and re-copy,
or the next refresh will overwrite your edit.

Licence: MPL-2.0, as the rest of the Tina4 stack.
