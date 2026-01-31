"""
model_worker.py
───────────────
Owns the TensorFlow model and exposes a single async helper:

    result = await run_inference(image_bytes)

Internally it:
  1. Decodes the JPEG/PNG bytes into an RGB numpy array.
  2. Offloads model.predict() to a ThreadPoolExecutor so the
     asyncio event loop is never blocked.
  3. Returns the top-K labels + confidences, filtered by threshold.

Frame-drop is handled at the *caller* level (WebSocket handler),
not here — this module is stateless and reentrant.
"""

import io
import logging
from concurrent.futures import ThreadPoolExecutor
from typing import Any

import numpy as np
from PIL import Image
from tensorflow.keras.models import load_model

from config import (
    CLASS_NAMES,
    CONFIDENCE_THRESHOLD,
    IMAGE_SIZE,
    MAX_INFERENCE_WORKERS,
    MODEL_PATH,
    TOP_K,
)

logger = logging.getLogger(__name__)

# ─── Load model once at import time ───────────────────────────────
logger.info("Loading model from %s …", MODEL_PATH)
_model = load_model(MODEL_PATH)
logger.info("Model loaded. Output classes: %d", _model.output_shape[-1])

if _model.output_shape[-1] != len(CLASS_NAMES):
    raise ValueError(
        f"Model output ({_model.output_shape[-1]} classes) != "
        f"CLASS_NAMES ({len(CLASS_NAMES)} classes). Retrain or update config."
    )

# ─── Thread pool for blocking inference ───────────────────────────
_executor = ThreadPoolExecutor(
    max_workers=MAX_INFERENCE_WORKERS,
    thread_name_prefix="inference",
)


# ─── Pure-Python helpers (run inside the thread pool) ─────────────
def _preprocess(image_bytes: bytes) -> np.ndarray:
    """Decode → RGB → resize → normalise → batch dim."""
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img = img.resize(IMAGE_SIZE)                          # (W, H) tuple
    arr = np.array(img, dtype=np.float32) / 255.0         # [0, 1]
    return np.expand_dims(arr, axis=0)                    # (1, H, W, 3)


def _predict_sync(image_bytes: bytes) -> list[dict[str, Any]]:
    """Blocking: preprocess + predict + format. Runs in executor thread."""
    tensor = _preprocess(image_bytes)
    raw = _model.predict(tensor, verbose=0)[0]           # shape (num_classes,)

    # Sort descending, take top K
    top_indices = raw.argsort()[-TOP_K:][::-1]

    results: list[dict[str, Any]] = []
    for idx in top_indices:
        confidence = round(float(raw[idx]) * 100, 2)
        if confidence >= CONFIDENCE_THRESHOLD:
            results.append({
                "label": CLASS_NAMES[idx],
                "confidence": confidence,
            })
    return results


# ─── Public async entry point ─────────────────────────────────────
import asyncio


async def run_inference(image_bytes: bytes) -> list[dict[str, Any]]:
    """
    Non-blocking inference.  Safe to call from any asyncio coroutine.

    Returns a list like:
        [{"label": "potholes", "confidence": 87.42}, …]
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(_executor, _predict_sync, image_bytes)