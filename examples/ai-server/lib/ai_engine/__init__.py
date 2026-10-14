"""Vendored model engine - loads a local model and exposes one small interface.

This is a self-contained snapshot of the inference code (model loader + MLX / torch
backends + the model downloader), so the AI server needs nothing cloned from
anywhere. Import ``ai_engine.model.load_model`` to get a model chosen for this
machine. See VENDOR.md for provenance and how to refresh it.
"""
