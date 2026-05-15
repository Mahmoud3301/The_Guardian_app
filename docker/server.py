"""
Guardian Security Backend
─────────────────────────
Runs ALL models on every frame simultaneously:
  1. yolov8n.pt      → General object detection (person, car, etc.)
  2. risk.pt         → Weapon/danger detection (gun, knife, etc.)
  3. home_object.pt  → Home object detection (cutter, tool, etc.)
  4. face_recognition → Face detection + recognition (known vs unknown)

Endpoints:
  - WebSocket /ws    for live video
  - POST /upload     for single image
  - POST /add_face   to register a new person
  - GET  /faces      list known people
  - GET  /health     status check

Supabase Storage integration for cloud face database sync.
"""

import os, cv2, json, base64, time, threading, io
import numpy as np
from datetime import datetime
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import face_recognition

try:
    from ultralytics import YOLO
except ImportError:
    YOLO = None

try:
    from supabase import create_client
    HAS_SUPABASE = True
except ImportError:
    HAS_SUPABASE = False

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(title="Guardian Security Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Config ────────────────────────────────────────────────────────────────────
PERSON_PHOTOS_DIR = os.environ.get("PERSON_PHOTOS_DIR", "/app/person_photos")
MODELS_DIR = os.environ.get("MODELS_DIR", "/app/custom_models")

# Supabase config
SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", "https://ldtqguseonfhkjfxuocl.supabase.co"
)
SUPABASE_KEY = os.environ.get(
    "SUPABASE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxkdHFndXNlb25maGtqZnh1b2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0MDgwNzMsImV4cCI6MjA5MDk4NDA3M30."
    "qSsDcm1rchiy3EWR9i3om3vZpII6F_iteGwaxr6XGNY",
)
SUPABASE_BUCKET = os.environ.get("SUPABASE_BUCKET", "DataBase")
SUPABASE_PHOTOS_PATH = "faces"

# ── ALL models ────────────────────────────────────────────────────────────────
yolo_general_model = None   # yolov8n.pt — person, car, etc.
risk_model = None           # risk.pt — gun, knife, weapon, etc.
home_object_model = None    # home_object.pt — cutter, tool, gloves, etc.

known_encodings: list = []
known_names: list = []
db_lock = threading.Lock()
supabase_client = None
models_ready = False        # Flag to show loading status

# ── Color palette for different model detections ──────────────────────────────
COLORS = {
    "face_known":    (0, 255, 0),      # Green
    "face_unknown":  (0, 165, 255),    # Orange
    "risk":          (0, 0, 255),      # Red
    "home_object":   (255, 200, 0),    # Cyan-ish
    "general":       (255, 255, 0),    # Cyan
}

# Risk class names to flag as dangerous
DANGER_KEYWORDS = [
    "gun", "knife", "facecover", "weapon", "axe", "sword",
    "machette", "shotgun", "grenade", "acid", "bat", "bow_and_arrow",
    "club", "crowbar", "cutter",
]


# ── Supabase helpers ─────────────────────────────────────────────────────────
def init_supabase():
    global supabase_client
    if not HAS_SUPABASE:
        print("[Supabase] supabase-py not installed — skipping cloud sync")
        return
    try:
        supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("[Supabase] Client initialized")
    except Exception as e:
        print(f"[Supabase] Init failed: {e}")


def sync_from_supabase():
    """Download any faces from Supabase that don't exist locally."""
    if supabase_client is None:
        return
    try:
        folders = supabase_client.storage.from_(SUPABASE_BUCKET).list(SUPABASE_PHOTOS_PATH)
        for folder in folders:
            person_name = folder.get("name", "")
            if not person_name:
                continue
            local_dir = os.path.join(PERSON_PHOTOS_DIR, person_name)
            os.makedirs(local_dir, exist_ok=True)

            files = supabase_client.storage.from_(SUPABASE_BUCKET).list(
                f"{SUPABASE_PHOTOS_PATH}/{person_name}"
            )
            for f in files:
                fname = f.get("name", "")
                if not fname.lower().endswith(('.jpg', '.jpeg', '.png')):
                    continue
                local_path = os.path.join(local_dir, fname)
                if os.path.exists(local_path):
                    continue
                try:
                    data = supabase_client.storage.from_(SUPABASE_BUCKET).download(
                        f"{SUPABASE_PHOTOS_PATH}/{person_name}/{fname}"
                    )
                    with open(local_path, "wb") as fp:
                        fp.write(data)
                    print(f"[Supabase] Downloaded {person_name}/{fname}")
                except Exception as e:
                    print(f"[Supabase] Download error {person_name}/{fname}: {e}")
        print("[Supabase] Sync from cloud complete")
    except Exception as e:
        print(f"[Supabase] Sync error: {e}")


def upload_to_supabase(person_name: str, img_bytes: bytes, filename: str = None):
    """Upload a face photo to Supabase Storage (non-blocking)."""
    if supabase_client is None:
        return
    normalized = person_name.lower().strip()
    if filename is None:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
        filename = f"face_{ts}.jpg"
    path = f"{SUPABASE_PHOTOS_PATH}/{normalized}/{filename}"
    try:
        supabase_client.storage.from_(SUPABASE_BUCKET).upload(
            path, img_bytes, {"content-type": "image/jpeg"}
        )
        latest_path = f"{SUPABASE_PHOTOS_PATH}/{normalized}/latest.jpg"
        try:
            supabase_client.storage.from_(SUPABASE_BUCKET).update(
                latest_path, img_bytes, {"content-type": "image/jpeg"}
            )
        except Exception:
            supabase_client.storage.from_(SUPABASE_BUCKET).upload(
                latest_path, img_bytes, {"content-type": "image/jpeg"}
            )
        print(f"[Supabase] Uploaded {path}")
    except Exception as e:
        print(f"[Supabase] Upload error: {e}")


# ── Face database ─────────────────────────────────────────────────────────────
def load_face_database():
    global known_encodings, known_names
    enc_list, name_list = [], []

    if not os.path.isdir(PERSON_PHOTOS_DIR):
        os.makedirs(PERSON_PHOTOS_DIR, exist_ok=True)

    for person_name in sorted(os.listdir(PERSON_PHOTOS_DIR)):
        person_dir = os.path.join(PERSON_PHOTOS_DIR, person_name)
        if not os.path.isdir(person_dir):
            continue
        for img_file in os.listdir(person_dir):
            if not img_file.lower().endswith(('.jpg', '.jpeg', '.png')):
                continue
            img_path = os.path.join(person_dir, img_file)
            try:
                img = face_recognition.load_image_file(img_path)
                encs = face_recognition.face_encodings(img)
                for enc in encs:
                    enc_list.append(enc)
                    name_list.append(person_name)
            except Exception as e:
                print(f"[DB] Error loading {img_path}: {e}")

    with db_lock:
        known_encodings = enc_list
        known_names = name_list
    print(f"[DB] Loaded {len(enc_list)} encodings for {len(set(name_list))} people")


# ── Frame processing — ALL MODELS AT ONCE ────────────────────────────────────
def process_frame(img_bytes: bytes) -> dict:
    arr = np.frombuffer(img_bytes, np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if frame is None:
        return {"error": "Could not decode image"}

    annotated = frame.copy()
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    is_known = None
    name = None
    distance_val = None
    risk_detected = False
    face_crop_b64 = None
    all_detections = []  # Collect all detections for the response

    # ─────────────────────────────────────────────────────────────────────────
    # MODEL 1: yolov8n.pt — General object detection
    # ─────────────────────────────────────────────────────────────────────────
    if yolo_general_model is not None:
        try:
            results = yolo_general_model(frame, conf=0.4, verbose=False)
            for box in results[0].boxes:
                cls = int(box.cls[0])
                conf = float(box.conf[0])
                label = yolo_general_model.names.get(cls, f"cls_{cls}")
                x1, y1, x2, y2 = map(int, box.xyxy[0])

                color = COLORS["general"]
                cv2.rectangle(annotated, (x1, y1), (x2, y2), color, 2)
                txt = f"{label} {conf:.0%}"
                (tw, th), _ = cv2.getTextSize(txt, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
                cv2.rectangle(annotated, (x1, y1 - th - 6), (x1 + tw + 4, y1), color, -1)
                cv2.putText(annotated, txt, (x1 + 2, y1 - 4),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)

                all_detections.append({
                    "model": "yolov8n",
                    "label": label,
                    "confidence": round(conf, 3),
                    "bbox": [x1, y1, x2, y2],
                })
        except Exception as e:
            print(f"[YOLOv8n] Error: {e}")

    # ─────────────────────────────────────────────────────────────────────────
    # MODEL 2: home_object.pt — Home object detection
    # ─────────────────────────────────────────────────────────────────────────
    if home_object_model is not None:
        try:
            results = home_object_model(frame, conf=0.4, verbose=False)
            for box in results[0].boxes:
                cls = int(box.cls[0])
                conf = float(box.conf[0])
                label = home_object_model.names.get(cls, f"obj_{cls}")
                x1, y1, x2, y2 = map(int, box.xyxy[0])

                color = COLORS["home_object"]
                cv2.rectangle(annotated, (x1, y1), (x2, y2), color, 2)
                txt = f"[HOME] {label} {conf:.0%}"
                (tw, th), _ = cv2.getTextSize(txt, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
                cv2.rectangle(annotated, (x1, y1 - th - 6), (x1 + tw + 4, y1), color, -1)
                cv2.putText(annotated, txt, (x1 + 2, y1 - 4),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)

                all_detections.append({
                    "model": "home_object",
                    "label": label,
                    "confidence": round(conf, 3),
                    "bbox": [x1, y1, x2, y2],
                })
        except Exception as e:
            print(f"[HomeObj] Error: {e}")

    # ─────────────────────────────────────────────────────────────────────────
    # MODEL 3: risk.pt — Risk / weapon detection
    # ─────────────────────────────────────────────────────────────────────────
    if risk_model is not None:
        try:
            results = risk_model(frame, conf=0.4, verbose=False)
            for box in results[0].boxes:
                cls = int(box.cls[0])
                conf = float(box.conf[0])
                label = risk_model.names.get(cls, f"risk_{cls}")
                x1, y1, x2, y2 = map(int, box.xyxy[0])

                is_danger = any(k in label.lower() for k in DANGER_KEYWORDS)
                if is_danger:
                    risk_detected = True

                color = COLORS["risk"] if is_danger else (128, 128, 255)
                thickness = 3 if is_danger else 2
                cv2.rectangle(annotated, (x1, y1), (x2, y2), color, thickness)
                prefix = "⚠ RISK" if is_danger else "risk"
                txt = f"{prefix}: {label} {conf:.0%}"
                (tw, th), _ = cv2.getTextSize(txt, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
                cv2.rectangle(annotated, (x1, y1 - th - 8), (x1 + tw + 4, y1), color, -1)
                cv2.putText(annotated, txt, (x1 + 2, y1 - 5),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

                all_detections.append({
                    "model": "risk",
                    "label": label,
                    "confidence": round(conf, 3),
                    "bbox": [x1, y1, x2, y2],
                    "is_danger": is_danger,
                })
        except Exception as e:
            print(f"[Risk] Error: {e}")

    # ─────────────────────────────────────────────────────────────────────────
    # MODEL 4: face_recognition — Face detection + recognition
    # ─────────────────────────────────────────────────────────────────────────
    face_locations = face_recognition.face_locations(rgb)

    if face_locations:
        face_encodings = face_recognition.face_encodings(rgb, face_locations)

        for (top, right, bottom, left), encoding in zip(face_locations, face_encodings):
            with db_lock:
                if len(known_encodings) > 0:
                    distances = face_recognition.face_distance(known_encodings, encoding)
                    best_idx = int(np.argmin(distances))
                    best_dist = float(distances[best_idx])
                    if best_dist < 0.5:
                        is_known = True
                        name = known_names[best_idx]
                        distance_val = best_dist
                        color = COLORS["face_known"]
                    else:
                        is_known = False
                        name = "Unknown"
                        distance_val = best_dist
                        color = COLORS["face_unknown"]
                else:
                    is_known = False
                    name = "Unknown"
                    color = COLORS["face_unknown"]

            # Draw face bounding box
            cv2.rectangle(annotated, (left, top), (right, bottom), color, 2)

            # Name label with background
            txt = f"{name}" + (f" ({distance_val:.2f})" if distance_val else "")
            (tw, th), _ = cv2.getTextSize(txt, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)
            cv2.rectangle(annotated, (left, top - th - 10), (left + tw + 4, top), color, -1)
            cv2.putText(annotated, txt, (left + 2, top - 5),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 2)

            # Crop unknown face
            if is_known is False:
                crop = frame[max(0, top):bottom, max(0, left):right]
                if crop.size > 0:
                    _, cjpg = cv2.imencode(".jpg", crop)
                    face_crop_b64 = base64.b64encode(cjpg.tobytes()).decode()

            all_detections.append({
                "model": "face_recognition",
                "label": name or "Unknown",
                "is_known": is_known,
                "distance": distance_val,
                "bbox": [left, top, right, bottom],
            })

    # ─────────────────────────────────────────────────────────────────────────
    # LEGEND — draw model status on the frame
    # ─────────────────────────────────────────────────────────────────────────
    h = frame.shape[0]
    legend_y = h - 10
    legend_items = [
        ("YOLO", yolo_general_model is not None, COLORS["general"]),
        ("HOME", home_object_model is not None, COLORS["home_object"]),
        ("RISK", risk_model is not None, COLORS["risk"]),
        ("FACE", True, COLORS["face_known"]),
    ]
    x_pos = 10
    for lbl, active, clr in legend_items:
        status_clr = clr if active else (80, 80, 80)
        cv2.circle(annotated, (x_pos + 5, legend_y - 4), 5, status_clr, -1)
        cv2.putText(annotated, lbl, (x_pos + 14, legend_y),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 255), 1)
        x_pos += 70

    # ── Encode result ─────────────────────────────────────────────────────────
    _, jpeg = cv2.imencode(".jpg", annotated, [cv2.IMWRITE_JPEG_QUALITY, 80])
    img_b64 = base64.b64encode(jpeg.tobytes()).decode()

    result = {
        "image": f"data:image/jpeg;base64,{img_b64}",
        "is_known": is_known,
        "name": name or "",
        "distance": distance_val,
        "risk_detected": risk_detected,
        "label": name if name else ("Risk!" if risk_detected else "No face detected"),
        "detections": all_detections,
        "models_active": {
            "yolov8n": yolo_general_model is not None,
            "home_object": home_object_model is not None,
            "risk": risk_model is not None,
            "face_recognition": True,
        },
    }
    if face_crop_b64:
        result["face_crop"] = f"data:image/jpeg;base64,{face_crop_b64}"
    return result


# ── Startup ───────────────────────────────────────────────────────────────────
@app.on_event("startup")
async def startup():
    """Start server IMMEDIATELY, load all models in background."""
    print("[Startup] Server starting — loading ALL models in background...")

    def _background_init():
        global yolo_general_model, risk_model, home_object_model, models_ready

        # 1) Init Supabase
        try:
            init_supabase()
        except Exception as e:
            print(f"[Startup] Supabase init failed (non-fatal): {e}")

        # 2) Sync from Supabase
        try:
            sync_from_supabase()
        except Exception as e:
            print(f"[Startup] Supabase sync failed (non-fatal): {e}")

        # 3) Load ALL YOLO models
        if YOLO is not None:
            # Model A: yolov8n.pt — General object detection
            yolo_path = os.path.join(MODELS_DIR, "yolov8n.pt")
            if os.path.exists(yolo_path):
                try:
                    yolo_general_model = YOLO(yolo_path)
                    print(f"[Model] ✅ yolov8n.pt loaded — general object detection")
                except Exception as e:
                    print(f"[Model] ❌ yolov8n.pt failed: {e}")
            else:
                print(f"[Model] ⚠ yolov8n.pt not found at {yolo_path}")

            # Model B: risk.pt — Risk/weapon detection
            risk_path = os.path.join(MODELS_DIR, "risk.pt")
            if os.path.exists(risk_path):
                try:
                    risk_model = YOLO(risk_path)
                    print(f"[Model] ✅ risk.pt loaded — weapon/danger detection")
                except Exception as e:
                    print(f"[Model] ❌ risk.pt failed: {e}")
            else:
                print(f"[Model] ⚠ risk.pt not found at {risk_path}")

            # Model C: home_object.pt — Home object detection
            home_path = os.path.join(MODELS_DIR, "home_object.pt")
            if os.path.exists(home_path):
                try:
                    home_object_model = YOLO(home_path)
                    print(f"[Model] ✅ home_object.pt loaded — home object detection")
                except Exception as e:
                    print(f"[Model] ❌ home_object.pt failed: {e}")
            else:
                print(f"[Model] ⚠ home_object.pt not found at {home_path}")

        # 4) Load face database
        load_face_database()

        models_ready = True
        active = sum([
            yolo_general_model is not None,
            risk_model is not None,
            home_object_model is not None,
            1,  # face_recognition always active
        ])
        print(f"[Startup] ✅ Background init complete! {active}/4 models active")

    threading.Thread(target=_background_init, daemon=True).start()


# ── Routes ────────────────────────────────────────────────────────────────────
@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await ws.accept()
    print("[WS] Client connected")
    try:
        while True:
            data = await ws.receive_text()
            if "," in data:
                data = data.split(",", 1)[1]
            img_bytes = base64.b64decode(data)
            result = process_frame(img_bytes)
            await ws.send_text(json.dumps(result))
    except WebSocketDisconnect:
        print("[WS] Client disconnected")
    except Exception as e:
        print(f"[WS] Error: {e}")


@app.post("/upload")
async def upload_image(file: UploadFile = File(...)):
    img_bytes = await file.read()
    if not img_bytes:
        return {"error": "Empty upload"}
    return process_frame(img_bytes)


@app.post("/add_face")
async def add_face(name: str = Form(...), file: UploadFile = File(...)):
    normalized = name.lower().strip()
    if not normalized:
        return JSONResponse({"error": "Name required"}, status_code=400)

    person_dir = os.path.join(PERSON_PHOTOS_DIR, normalized)
    os.makedirs(person_dir, exist_ok=True)

    img_bytes = await file.read()
    ts = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]

    for fname in [f"face_{ts}.jpg", "latest.jpg"]:
        with open(os.path.join(person_dir, fname), "wb") as f:
            f.write(img_bytes)

    threading.Thread(
        target=upload_to_supabase,
        args=(normalized, img_bytes, f"face_{ts}.jpg"),
        daemon=True,
    ).start()

    load_face_database()
    return {"status": "ok", "name": name}


@app.get("/faces")
async def list_faces():
    with db_lock:
        return {"faces": sorted(set(known_names)), "total": len(known_encodings)}


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "models_ready": models_ready,
        "yolo_general": yolo_general_model is not None,
        "risk_model": risk_model is not None,
        "home_object_model": home_object_model is not None,
        "face_recognition": True,
        "known_faces": len(set(known_names)),
        "supabase_connected": supabase_client is not None,
    }


if __name__ == "__main__":
    import uvicorn
    print(f"[App] person_photos: {PERSON_PHOTOS_DIR}")
    print(f"[App] models: {MODELS_DIR}")
    uvicorn.run(app, host="0.0.0.0", port=8000)
