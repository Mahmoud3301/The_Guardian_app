"""
Guardian Security Backend
─────────────────────────
Runs ALL models on every frame simultaneously:
  1. yolov8n.pt      → General object detection (person, car, etc.)
  2. risk.pt         → Weapon/danger detection (gun, knife, etc.)
  3. home_object.pt  → Home object detection (cutter, tool, etc.)
  4. face_recognition → Face detection + recognition (known vs unknown)

Owner-based risk logic:
  - If a KNOWN OWNER is detected with an object → SAFE
  - If an UNKNOWN person is detected with an object → RISK

mDNS (Avahi) auto-discovery:
  - Publishes "_guardian._tcp" service on the local network
  - Flutter app discovers the backend automatically via mDNS

Endpoints:
  - WebSocket /ws    for live video
  - POST /upload     for single image
  - POST /add_face   to register a new person
  - GET  /faces      list known people
  - GET  /health     status check
  - GET  /owners     list owner names

Supabase Storage integration for cloud face database sync.
"""

import os, cv2, json, base64, time, threading, io, socket
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

# Try to import zeroconf for mDNS
try:
    from zeroconf import ServiceInfo, Zeroconf
    HAS_ZEROCONF = True
except ImportError:
    HAS_ZEROCONF = False

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

# ── Owner list — people registered as owners (lowercase) ─────────────────────
OWNERS = set()  # populated from person_photos directory or /owners endpoint
OWNERS_LOCK = threading.Lock()

# ── ALL models ────────────────────────────────────────────────────────────────
yolo_general_model = None   # yolov8n.pt — person, car, etc.
risk_model = None           # risk.pt — gun, knife, weapon, etc.
home_object_model = None    # home_object.pt — cutter, tool, gloves, etc.

known_encodings: list = []
known_names: list = []
db_lock = threading.Lock()
supabase_client = None
models_ready = False        # Flag to show loading status
zeroconf_instance = None    # mDNS service

# ── Color palette for different model detections ──────────────────────────────
COLORS = {
    "face_known":    (0, 255, 0),      # Green
    "face_unknown":  (0, 165, 255),    # Orange
    "risk":          (0, 0, 255),      # Red
    "safe":          (0, 255, 128),    # Green-ish (owner + object = safe)
    "home_object":   (255, 200, 0),    # Cyan-ish
    "general":       (255, 255, 0),    # Cyan
}

# All potentially dangerous class names across all models
DANGER_KEYWORDS = [
    "gun", "knife", "facecover", "weapon", "axe", "sword",
    "machette", "shotgun", "grenade", "acid", "bat", "bow_and_arrow",
    "club", "crowbar", "cutter", "scissors", "hammer", "screwdriver",
    "pliers", "wrench", "saw",
]


# ── mDNS / Avahi helpers ────────────────────────────────────────────────────
def get_local_ip():
    """Get the local IP address of this machine."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def register_mdns_service():
    """Register the Guardian backend as an mDNS service so apps can discover it."""
    global zeroconf_instance
    if not HAS_ZEROCONF:
        print("[mDNS] zeroconf not installed — trying avahi-publish fallback")
        _try_avahi_fallback()
        return

    try:
        local_ip = get_local_ip()
        ip_bytes = socket.inet_aton(local_ip)

        info = ServiceInfo(
            "_guardian._tcp.local.",
            "Guardian Security Backend._guardian._tcp.local.",
            addresses=[ip_bytes],
            port=8000,
            properties={
                "version": "2.0",
                "path": "/",
            },
            server="guardian-backend.local.",
        )

        zeroconf_instance = Zeroconf()
        zeroconf_instance.register_service(info)
        print(f"[mDNS] ✅ Service registered: _guardian._tcp on {local_ip}:8000")
    except Exception as e:
        print(f"[mDNS] Registration failed: {e}")
        _try_avahi_fallback()


def _try_avahi_fallback():
    """Try to use avahi-publish-service as fallback for mDNS."""
    try:
        import subprocess
        proc = subprocess.Popen(
            [
                "avahi-publish-service",
                "Guardian Security Backend",
                "_guardian._tcp",
                "8000",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        print(f"[mDNS] ✅ avahi-publish-service started (PID: {proc.pid})")
    except FileNotFoundError:
        print("[mDNS] ⚠ Neither zeroconf nor avahi-publish available")
    except Exception as e:
        print(f"[mDNS] avahi fallback failed: {e}")


def unregister_mdns_service():
    """Unregister the mDNS service on shutdown."""
    global zeroconf_instance
    if zeroconf_instance is not None:
        try:
            zeroconf_instance.unregister_all_services()
            zeroconf_instance.close()
            print("[mDNS] Service unregistered")
        except Exception:
            pass


# ── Owner management ─────────────────────────────────────────────────────────
def load_owners():
    """Load owner list from person_photos directory.
    All people who have photos in person_photos are considered owners."""
    global OWNERS
    owners = set()
    if os.path.isdir(PERSON_PHOTOS_DIR):
        for name in os.listdir(PERSON_PHOTOS_DIR):
            if os.path.isdir(os.path.join(PERSON_PHOTOS_DIR, name)):
                owners.add(name.lower().strip())
    with OWNERS_LOCK:
        OWNERS = owners
    print(f"[Owners] Loaded {len(OWNERS)} owners: {OWNERS}")


def is_owner(name: str) -> bool:
    """Check if a person name is a registered owner."""
    if not name:
        return False
    with OWNERS_LOCK:
        return name.lower().strip() in OWNERS


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


# ── Helper: check if bounding boxes overlap ──────────────────────────────────
def boxes_overlap(box1, box2, threshold=0.1):
    """Check if two bounding boxes overlap significantly.
    box format: [x1, y1, x2, y2]"""
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])

    if x2 <= x1 or y2 <= y1:
        return False

    intersection = (x2 - x1) * (y2 - y1)
    area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
    area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])

    if area1 <= 0 or area2 <= 0:
        return False

    # IoU-like check: intersection over minimum area
    min_area = min(area1, area2)
    return (intersection / min_area) > threshold


def boxes_near(box1, box2, margin=150):
    """Check if two boxes are near each other (within margin pixels)."""
    cx1 = (box1[0] + box1[2]) / 2
    cy1 = (box1[1] + box1[3]) / 2
    cx2 = (box2[0] + box2[2]) / 2
    cy2 = (box2[1] + box2[3]) / 2
    dist = ((cx1 - cx2)**2 + (cy1 - cy2)**2) ** 0.5
    return dist < margin


# ── Frame processing — ALL MODELS AT ONCE ────────────────────────────────────
def process_frame(img_bytes: bytes) -> dict:
    arr = np.frombuffer(img_bytes, np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if frame is None:
        return {"error": "Could not decode image"}

    annotated = frame.copy()
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    detected_name = None
    is_known = None
    distance_val = None
    risk_detected = False
    face_crop_b64 = None
    all_detections = []
    face_boxes = []  # Store face boxes for proximity check
    person_boxes = []  # Store person (general YOLO) boxes

    # ─────────────────────────────────────────────────────────────────────────
    # MODEL 4 FIRST: face_recognition — detect who is in the frame
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
                        detected_name = known_names[best_idx]
                        distance_val = best_dist
                        color = COLORS["face_known"]
                    else:
                        is_known = False
                        detected_name = "Unknown"
                        distance_val = best_dist
                        color = COLORS["face_unknown"]
                else:
                    is_known = False
                    detected_name = "Unknown"
                    color = COLORS["face_unknown"]

            face_box = [left, top, right, bottom]
            face_boxes.append({
                "box": face_box,
                "name": detected_name,
                "is_known": is_known,
                "is_owner": is_owner(detected_name) if is_known else False,
            })

            # Draw face bounding box
            cv2.rectangle(annotated, (left, top), (right, bottom), color, 2)
            txt = f"{detected_name}" + (f" ({distance_val:.2f})" if distance_val else "")
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
                "label": detected_name or "Unknown",
                "is_known": is_known,
                "is_owner": is_owner(detected_name) if is_known else False,
                "distance": distance_val,
                "bbox": face_box,
            })

    # Determine if there's an owner in the frame
    owner_in_frame = any(fb["is_owner"] for fb in face_boxes)
    # Determine the closest known face for object association
    known_face_in_frame = any(fb["is_known"] for fb in face_boxes)

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

                # Track person boxes
                if label.lower() == "person":
                    person_boxes.append([x1, y1, x2, y2])

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
    # Owner + home object = SAFE, Unknown + home object = RISK
    # ─────────────────────────────────────────────────────────────────────────
    if home_object_model is not None:
        try:
            results = home_object_model(frame, conf=0.4, verbose=False)
            for box in results[0].boxes:
                cls = int(box.cls[0])
                conf = float(box.conf[0])
                label = home_object_model.names.get(cls, f"obj_{cls}")
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                obj_box = [x1, y1, x2, y2]

                # Determine if this object is near an owner or unknown
                near_owner = False
                near_unknown = False
                for fb in face_boxes:
                    if boxes_near(obj_box, fb["box"], margin=250):
                        if fb["is_owner"]:
                            near_owner = True
                        elif not fb["is_known"]:
                            near_unknown = True

                # If owner is using the home object → SAFE
                # If unknown person → RISK
                if near_owner and not near_unknown:
                    status = "SAFE"
                    color = COLORS["safe"]
                    thickness = 2
                elif near_unknown:
                    status = "RISK"
                    color = COLORS["risk"]
                    thickness = 3
                    risk_detected = True
                elif owner_in_frame and not near_unknown:
                    status = "SAFE"
                    color = COLORS["safe"]
                    thickness = 2
                else:
                    # No face detected with object — treat as risk
                    status = "RISK"
                    color = COLORS["risk"]
                    thickness = 3
                    if not owner_in_frame:
                        risk_detected = True

                cv2.rectangle(annotated, (x1, y1), (x2, y2), color, thickness)
                txt = f"[{status}] {label} {conf:.0%}"
                (tw, th), _ = cv2.getTextSize(txt, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
                cv2.rectangle(annotated, (x1, y1 - th - 6), (x1 + tw + 4, y1), color, -1)
                fg_color = (0, 0, 0) if status == "SAFE" else (255, 255, 255)
                cv2.putText(annotated, txt, (x1 + 2, y1 - 4),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, fg_color, 1)

                all_detections.append({
                    "model": "home_object",
                    "label": label,
                    "confidence": round(conf, 3),
                    "bbox": [x1, y1, x2, y2],
                    "status": status,
                    "near_owner": near_owner,
                })
        except Exception as e:
            print(f"[HomeObj] Error: {e}")

    # ─────────────────────────────────────────────────────────────────────────
    # MODEL 3: risk.pt — Risk / weapon detection
    # Owner + risk object = SAFE (e.g. knife in kitchen for cooking)
    # Unknown + risk object = RISK
    # ─────────────────────────────────────────────────────────────────────────
    if risk_model is not None:
        try:
            results = risk_model(frame, conf=0.4, verbose=False)
            for box in results[0].boxes:
                cls = int(box.cls[0])
                conf = float(box.conf[0])
                label = risk_model.names.get(cls, f"risk_{cls}")
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                obj_box = [x1, y1, x2, y2]

                is_danger_class = any(k in label.lower() for k in DANGER_KEYWORDS)

                # Determine context: who is near this object?
                near_owner = False
                near_unknown = False
                for fb in face_boxes:
                    if boxes_near(obj_box, fb["box"], margin=250):
                        if fb["is_owner"]:
                            near_owner = True
                        elif not fb["is_known"]:
                            near_unknown = True

                # Owner with a dangerous object → SAFE (cooking, working, etc.)
                # Unknown with dangerous object → RISK
                if near_owner and not near_unknown:
                    status = "SAFE"
                    color = COLORS["safe"]
                    thickness = 2
                elif near_unknown:
                    status = "RISK"
                    color = COLORS["risk"]
                    thickness = 3
                    risk_detected = True
                elif owner_in_frame and not near_unknown:
                    # Owner is in frame but object not near anyone specifically
                    status = "SAFE"
                    color = COLORS["safe"]
                    thickness = 2
                else:
                    # No recognized person → default to risk for dangerous items
                    if is_danger_class:
                        status = "RISK"
                        color = COLORS["risk"]
                        thickness = 3
                        risk_detected = True
                    else:
                        status = "SAFE"
                        color = COLORS["safe"]
                        thickness = 2

                cv2.rectangle(annotated, (x1, y1), (x2, y2), color, thickness)
                icon = "✓" if status == "SAFE" else "⚠"
                txt = f"{icon} {status}: {label} {conf:.0%}"
                (tw, th), _ = cv2.getTextSize(txt, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
                cv2.rectangle(annotated, (x1, y1 - th - 8), (x1 + tw + 4, y1), color, -1)
                fg_color = (0, 0, 0) if status == "SAFE" else (255, 255, 255)
                cv2.putText(annotated, txt, (x1 + 2, y1 - 5),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, fg_color, 2)

                all_detections.append({
                    "model": "risk",
                    "label": label,
                    "confidence": round(conf, 3),
                    "bbox": [x1, y1, x2, y2],
                    "status": status,
                    "is_danger_class": is_danger_class,
                    "near_owner": near_owner,
                })
        except Exception as e:
            print(f"[Risk] Error: {e}")

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

    # Owner status indicator
    owner_txt = "OWNER" if owner_in_frame else "NO OWNER"
    owner_clr = (0, 255, 128) if owner_in_frame else (0, 0, 255)
    cv2.putText(annotated, owner_txt, (x_pos + 14, legend_y),
                cv2.FONT_HERSHEY_SIMPLEX, 0.4, owner_clr, 1)

    # ── Encode result ─────────────────────────────────────────────────────────
    _, jpeg = cv2.imencode(".jpg", annotated, [cv2.IMWRITE_JPEG_QUALITY, 80])
    img_b64 = base64.b64encode(jpeg.tobytes()).decode()

    result = {
        "image": f"data:image/jpeg;base64,{img_b64}",
        "is_known": is_known,
        "name": detected_name or "",
        "is_owner": is_owner(detected_name) if detected_name and is_known else False,
        "distance": distance_val,
        "risk_detected": risk_detected,
        "owner_in_frame": owner_in_frame,
        "label": detected_name if detected_name else ("Risk!" if risk_detected else "No face detected"),
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

        # 0) Register mDNS service
        try:
            register_mdns_service()
        except Exception as e:
            print(f"[Startup] mDNS registration failed (non-fatal): {e}")

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

        # 4) Load face database + owners
        load_face_database()
        load_owners()

        models_ready = True
        active = sum([
            yolo_general_model is not None,
            risk_model is not None,
            home_object_model is not None,
            1,  # face_recognition always active
        ])
        print(f"[Startup] ✅ Background init complete! {active}/4 models active")

    threading.Thread(target=_background_init, daemon=True).start()


@app.on_event("shutdown")
async def shutdown():
    unregister_mdns_service()


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
    load_owners()  # Refresh owners list
    return {"status": "ok", "name": name}


@app.get("/faces")
async def list_faces():
    with db_lock:
        return {"faces": sorted(set(known_names)), "total": len(known_encodings)}


@app.get("/owners")
async def list_owners():
    """List all registered owners."""
    with OWNERS_LOCK:
        return {"owners": sorted(OWNERS), "total": len(OWNERS)}


@app.get("/health")
async def health():
    local_ip = get_local_ip()
    return {
        "status": "ok",
        "models_ready": models_ready,
        "yolo_general": yolo_general_model is not None,
        "risk_model": risk_model is not None,
        "home_object_model": home_object_model is not None,
        "face_recognition": True,
        "known_faces": len(set(known_names)),
        "owners": sorted(OWNERS),
        "supabase_connected": supabase_client is not None,
        "local_ip": local_ip,
        "mdns_name": "guardian-backend.local",
    }


if __name__ == "__main__":
    import uvicorn
    print(f"[App] person_photos: {PERSON_PHOTOS_DIR}")
    print(f"[App] models: {MODELS_DIR}")
    print(f"[App] Local IP: {get_local_ip()}")
    uvicorn.run(app, host="0.0.0.0", port=8000)
