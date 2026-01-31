"""
main.py
───────
FastAPI application.

Endpoints
─────────
  GET  /              Health banner
  GET  /health        Machine-readable health + model meta
  POST /predict-image Single-shot HTTP image upload (original endpoint)
  WS   /ws/predict    Streaming real-time prediction over WebSocket

WebSocket protocol (text frames, JSON):
  Client → Server:  {"frame": "<base64-encoded JPEG bytes>"}
  Server → Client:  {"predictions": [...], "latency_ms": <float>}
                 or {"error": "<message>"}

Frame-drop strategy
───────────────────
Each connection keeps an *asyncio.Event* called `_busy`.
While inference is running for a previous frame the event is set.
If a new frame arrives while busy the old pending frame is replaced —
only the *latest* frame is ever processed.  This keeps end-to-end
latency low even if the client sends frames faster than the model
can consume them.
"""

import base64
import io
import logging
import time
from typing import Any

import uvicorn
from fastapi import FastAPI, File, Request, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import (
    ALLOWED_MIME_TYPES,
    HOST,
    MAX_UPLOAD_BYTES,
    PORT,
    WS_MAX_MESSAGE_BYTES,
)
from model_worker import run_inference

# ─── Logging ──────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# ─── App ──────────────────────────────────────────────────────────
app = FastAPI(
    title="Real-Time Image Detection",
    description="Single-shot HTTP + WebSocket streaming prediction API.",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # Tighten to your Flutter origin in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Global exception handler ─────────────────────────────────────
@app.exception_handler(Exception)
async def _global_exc(request: Request, exc: Exception):
    logger.error("Unhandled: %s", exc, exc_info=True)
    return JSONResponse(status_code=500, content={"error": "Internal server error"})


# ─── Root / Health ────────────────────────────────────────────────
@app.get("/")
async def root():
    return {"message": "Real-Time Image Detection API is running.", "docs": "/docs"}


@app.get("/health")
async def health():
    from config import CLASS_NAMES
    return {"status": "ok", "num_classes": len(CLASS_NAMES), "classes": CLASS_NAMES}


# ─── Single-shot HTTP endpoint (kept from v1) ─────────────────────
@app.post("/predict-image")
async def predict_image(file: UploadFile = File(...)):
    if file.content_type not in ALLOWED_MIME_TYPES:
        return JSONResponse(
            status_code=400,
            content={"error": f"Unsupported type '{file.content_type}'."},
        )

    contents = await file.read()
    if len(contents) > MAX_UPLOAD_BYTES:
        return JSONResponse(status_code=400, content={"error": "File too large."})

    try:
        predictions = await run_inference(contents)
        return JSONResponse(content={"filename": file.filename, "predictions": predictions})
    except Exception as e:
        logger.error("predict_image error: %s", e, exc_info=True)
        return JSONResponse(status_code=400, content={"error": str(e)})


# ─── WebSocket streaming endpoint ─────────────────────────────────
import asyncio
import json


@app.websocket("/ws/predict")
async def ws_predict(websocket: WebSocket):
    """
    Real-time prediction stream.

    The client sends JSON frames:   {"frame": "<base64 JPEG>"}
    The server replies with:        {"predictions": [...], "latency_ms": <float>}

    Frame-drop: while a prediction is in flight, any incoming frame
    *replaces* the pending one so only the freshest frame is processed.
    """
    await websocket.accept()
    logger.info("WebSocket connected: %s", websocket.client)

    # Shared mutable state for this connection — no lock needed because
    # everything runs on the single asyncio thread.
    pending_frame: list[bytes | None] = [None]   # list trick for nonlocal mutation
    busy = asyncio.Event()                        # set while inference is running

    async def _inference_loop():
        """Continuously picks up pending frames and runs inference."""
        while True:
            # Wait until a frame is available
            while pending_frame[0] is None:
                await asyncio.sleep(0.01)

            busy.set()
            frame_bytes = pending_frame[0]
            pending_frame[0] = None          # consume

            t0 = time.perf_counter()
            try:
                predictions = await run_inference(frame_bytes)
                latency = round((time.perf_counter() - t0) * 1000, 1)
                await websocket.send_json({
                    "predictions": predictions,
                    "latency_ms": latency,
                })
            except Exception as e:
                logger.error("Inference error: %s", e, exc_info=True)
                try:
                    await websocket.send_json({"error": str(e)})
                except Exception:
                    break          # connection probably dead
            finally:
                busy.clear()

    # Start inference loop as a background task on this connection
    loop_task = asyncio.create_task(_inference_loop())

    try:
        while True:
            raw = await websocket.receive_text()

            # Size guard (base64 expands ~33 %, so check decoded estimate)
            if len(raw) > WS_MAX_MESSAGE_BYTES * 1.4:
                await websocket.send_json({"error": "Frame too large."})
                continue

            try:
                msg: dict[str, Any] = json.loads(raw)
            except json.JSONDecodeError:
                await websocket.send_json({"error": "Invalid JSON."})
                continue

            if "frame" not in msg:
                await websocket.send_json({"error": "Missing 'frame' key."})
                continue

            try:
                frame_bytes = base64.b64decode(msg["frame"])
            except Exception:
                await websocket.send_json({"error": "Invalid base64 in 'frame'."})
                continue

            # Drop previous pending frame — only keep the latest
            pending_frame[0] = frame_bytes

    except WebSocketDisconnect:
        logger.info("WebSocket disconnected: %s", websocket.client)
    finally:
        loop_task.cancel()
        try:
            await loop_task
        except asyncio.CancelledError:
            pass


# ─── Entry point ──────────────────────────────────────────────────
if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT)