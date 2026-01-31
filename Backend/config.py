"""
config.py
─────────
Single source of truth for every tuneable constant.
Change behaviour here; never scatter magic numbers across other files.
"""

import os

# ─── Model ────────────────────────────────────────────────────────
MODEL_PATH: str = os.getenv("MODEL_PATH", "model.keras")
IMAGE_SIZE: tuple[int, int] = (128, 128)   # Must match training exactly

CLASS_NAMES: list[str] = [
    "animals",
    "barriers",
    "busstop",
    "cables",
    "clear_path",
    "construction_site",
    "crosswalk",
    "doors",
    "elevators",
    "fire",
    "fire_exits",
    "potholes",
    "slippery_surface",
    "speed_bumps",
    "staircases",
    "streetlight_poles",
    "traffic_lights",
    "trash_bins",
    "vehicles",
    "walls",
]

# ─── Inference tuning ─────────────────────────────────────────────
# How many labels to return per prediction
TOP_K: int = 3

# Minimum confidence (0-100) to include a label in the response.
# Anything below this is filtered out entirely.
CONFIDENCE_THRESHOLD: float = 5.0

# Max concurrent model.predict() calls (one thread each).
# Keep ≤ CPU core count to avoid thrashing.  GPU ignores this.
MAX_INFERENCE_WORKERS: int = int(os.getenv("MAX_INFERENCE_WORKERS", "2"))

# ─── WebSocket / streaming ────────────────────────────────────────
# Max size (bytes) of a single WebSocket message we accept.
# 2 MB covers a full-res JPEG from most phones.
WS_MAX_MESSAGE_BYTES: int = 2 * 1024 * 1024

# ─── HTTP upload (single-shot endpoint) ───────────────────────────
ALLOWED_MIME_TYPES: set[str] = {
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/bmp",
    "image/webp",
}
MAX_UPLOAD_BYTES: int = 10 * 1024 * 1024   # 10 MB

# ─── Server ───────────────────────────────────────────────────────
HOST: str = os.getenv("HOST", "0.0.0.0")
PORT: int = int(os.getenv("PORT", "8000"))