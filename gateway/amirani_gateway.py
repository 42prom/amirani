#!/usr/bin/env python3
"""
Amirani Gateway Firmware
Runs on Raspberry Pi at gym entrance.

Supports:
  - NFC/RFID card reading (MFRC522 via SPI, or ACR122U via USB)
  - PIN entry via 4x4 matrix keypad
  - Door relay control via GPIO
  - Real-time WebSocket commands from dashboard ("Open Door" button)
  - REST fallback polling if WebSocket drops
  - LED + buzzer feedback
  - Small OLED display (optional)

Hardware bill of materials (~$35 total):
  - Raspberry Pi Zero 2W or Pi 4          ~$15-35
  - MFRC522 RFID/NFC reader module        ~$3
  - 4x4 matrix keypad (optional)          ~$3
  - 5V relay module (single channel)      ~$3
  - Green + Red LEDs + resistors          ~$1
  - Buzzer (active, 5V)                   ~$1
  - SSD1306 0.96" OLED display (optional) ~$4
  - Jumper wires + breadboard             ~$3

Wiring:
  MFRC522  → SPI0 (SDA=GPIO8, SCK=GPIO11, MOSI=GPIO10, MISO=GPIO9, RST=GPIO25)
  Relay    → GPIO18 (HIGH = unlock, LOW = lock)
  Green LED→ GPIO23
  Red LED  → GPIO24
  Buzzer   → GPIO27
  Keypad   → GPIO rows: 5,6,13,19  cols: 26,16,20,21
  OLED     → I2C (SDA=GPIO2, SCL=GPIO3)
"""

import sys
import os
import time
import json
import threading
import logging
import requests
import socketio

# ─── Config ───────────────────────────────────────────────────────────────────

CONFIG_FILE = os.path.join(os.path.dirname(__file__), "config.json")

def load_config():
    if not os.path.exists(CONFIG_FILE):
        print("[ERROR] config.json not found. Copy config.example.json and fill in your values.")
        sys.exit(1)
    # Security: config.json contains the API key. Enforce 0600 permissions at startup.
    # Provision step: sudo chmod 600 config.json && sudo chown pi:pi config.json
    stat = os.stat(CONFIG_FILE)
    if stat.st_mode & 0o077:  # any group or other read/write bits set
        print("[WARN] config.json has overly permissive file permissions. Run: chmod 600 config.json")
    with open(CONFIG_FILE) as f:
        return json.load(f)

cfg = load_config()

API_KEY      = cfg["api_key"]
BACKEND_URL  = cfg.get("backend_url", "https://amirani.esme.ge")
RELAY_PIN    = cfg.get("relay_pin", 18)
LED_GREEN    = cfg.get("led_green_pin", 23)
LED_RED      = cfg.get("led_red_pin", 24)
BUZZER_PIN   = cfg.get("buzzer_pin", 27)
USE_KEYPAD   = cfg.get("use_keypad", False)
USE_DISPLAY  = cfg.get("use_display", False)
USE_NFC      = cfg.get("use_nfc", True)
NFC_READER   = cfg.get("nfc_reader", "mfrc522")   # "mfrc522" or "acr122u"
PIN_TIMEOUT  = cfg.get("pin_timeout_s", 8)         # seconds to complete PIN entry
UNLOCK_MS    = cfg.get("unlock_duration_ms", 3000)

# ─── Logging ──────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(), logging.FileHandler("/var/log/amirani-gateway.log")]
)
log = logging.getLogger("gateway")

# ─── GPIO Setup ───────────────────────────────────────────────────────────────

try:
    import RPi.GPIO as GPIO
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(RELAY_PIN, GPIO.OUT, initial=GPIO.LOW)
    GPIO.setup(LED_GREEN,  GPIO.OUT, initial=GPIO.LOW)
    GPIO.setup(LED_RED,    GPIO.OUT, initial=GPIO.LOW)
    GPIO.setup(BUZZER_PIN, GPIO.OUT, initial=GPIO.LOW)
    HAS_GPIO = True
    log.info("GPIO initialized")
except ImportError:
    HAS_GPIO = False
    log.warning("RPi.GPIO not available — running in simulation mode")

# ─── NFC Reader ───────────────────────────────────────────────────────────────

nfc_reader = None

def init_nfc():
    global nfc_reader
    if not USE_NFC:
        return
    if NFC_READER == "mfrc522":
        try:
            from mfrc522 import SimpleMFRC522
            nfc_reader = SimpleMFRC522()
            log.info("MFRC522 NFC reader initialized")
        except Exception as e:
            log.error(f"MFRC522 init failed: {e}")
    elif NFC_READER == "acr122u":
        try:
            import nfc
            nfc_reader = "acr122u"
            log.info("ACR122U reader will be used via nfcpy")
        except Exception as e:
            log.error(f"nfcpy init failed: {e}")

def read_nfc_uid_mfrc522():
    """
    Read NFC credential from MFRC522.

    For physical cards: returns the ISO 14443-3 UID (hex string).
    For Android phones (HCE): attempts ISO 14443-4 APDU exchange to retrieve
    the stable Amirani credential, falling back to basic UID if APDU fails.

    Returns hex credential string or None on error.
    """
    try:
        from mfrc522 import MFRC522
        raw_reader = MFRC522()

        # ── Detect card ───────────────────────────────────────────────────────
        status, _ = raw_reader.MFRC522_Request(raw_reader.PICC_REQIDL)
        if status != raw_reader.MI_OK:
            return None

        # ── Anti-collision / get UID ──────────────────────────────────────────
        status, uid_bytes = raw_reader.MFRC522_Anticoll()
        if status != raw_reader.MI_OK:
            return None

        basic_uid = ''.join(f'{b:02X}' for b in uid_bytes[:4])

        # ── SELECT tag / get SAK ─────────────────────────────────────────────
        raw_reader.MFRC522_SelectTag(uid_bytes)
        # SAK bit 5 (0x20) set → card supports ISO 14443-4 (T=CL)
        # Try APDU exchange to get stable Amirani HCE credential
        apdu_cred = _try_apdu_credential(raw_reader)
        if apdu_cred:
            log.info(f"[NFC] HCE credential via APDU: {apdu_cred}")
            return apdu_cred

        log.info(f"[NFC] Basic UID: {basic_uid}")
        return basic_uid

    except ImportError:
        # Fall back to SimpleMFRC522 if raw MFRC522 class not available
        try:
            uid, _ = nfc_reader.read()
            return format(uid, 'X').upper()
        except Exception as e:
            log.error(f"NFC read error (simple): {e}")
            time.sleep(1)
            return None
    except Exception as e:
        log.error(f"NFC read error: {e}")
        time.sleep(1)
        return None


# AID: F0 4D 49 52 41 4E 49  (F0 + "MIRANI") — must match AmiraniHceService.kt
_AMIRANI_AID = [0xF0, 0x4D, 0x49, 0x52, 0x41, 0x4E, 0x49]


def _try_apdu_credential(reader):
    """
    Attempt ISO 14443-4 APDU exchange with an Amirani HCE phone.

    Sends:
      1. RATS (activate T=CL)
      2. SELECT AID  [00 A4 04 00 07 F0 4D 49 52 41 4E 49 00]
      3. GET CRED    [00 CA 00 00 08]

    Returns 16-char hex credential string on success, or None.
    """
    try:
        # RATS — Request ATS (FSDI=5 → up to 64 bytes, CID=0)
        rats = [0xE0, 0x50]
        status, _, _ = reader.MFRC522_ToCard(reader.PCD_TRANSCEIVE, rats)
        if status != reader.MI_OK:
            return None  # Card doesn't support ISO 14443-4

        # I-block PCB counters (alternate 0x02 / 0x03)
        block_num = [0]

        def send_apdu(apdu_bytes):
            pcb = 0x02 | (block_num[0] & 0x01)  # I-block, no chaining
            block_num[0] += 1
            frame = [pcb] + list(apdu_bytes)
            st, resp, _ = reader.MFRC522_ToCard(reader.PCD_TRANSCEIVE, frame)
            if st != reader.MI_OK or not resp:
                return None
            # Strip PCB byte from response
            return resp[1:] if len(resp) > 1 else resp

        # SELECT AID
        select = [0x00, 0xA4, 0x04, 0x00, len(_AMIRANI_AID)] + _AMIRANI_AID + [0x00]
        resp = send_apdu(select)
        if resp is None or resp[-2:] != [0x90, 0x00]:
            return None

        # GET CREDENTIAL (CLA=00 INS=CA P1=00 P2=00 Le=08)
        get_cred = [0x00, 0xCA, 0x00, 0x00, 0x08]
        resp = send_apdu(get_cred)
        if resp is None or len(resp) < 10 or resp[-2:] != [0x90, 0x00]:
            return None

        cred_bytes = resp[:8]
        return ''.join(f'{b:02X}' for b in cred_bytes)

    except Exception as e:
        log.debug(f"[NFC] APDU exchange failed (not HCE phone): {e}")
        return None


def read_nfc_uid_acr122u():
    """
    Non-blocking poll via nfcpy (ACR122U USB reader).

    For Android HCE phones, nfcpy can exchange APDUs natively.
    For physical cards, returns the tag UID.
    """
    import nfc
    result = [None]

    def on_connect(tag):
        # Try Amirani HCE APDU exchange first
        try:
            if hasattr(tag, 'send_apdu'):
                aid = bytes(_AMIRANI_AID)
                select = bytes([0x00, 0xA4, 0x04, 0x00, len(aid)]) + aid + b'\x00'
                resp = tag.send_apdu(*[int(b) for b in select])
                if resp[-2:] == b'\x90\x00':
                    get_cred = bytes([0x00, 0xCA, 0x00, 0x00, 0x08])
                    resp2 = tag.send_apdu(*[int(b) for b in get_cred])
                    if len(resp2) >= 10 and resp2[-2:] == b'\x90\x00':
                        result[0] = resp2[:8].hex().upper()
                        log.info(f"[NFC] ACR122U HCE credential: {result[0]}")
                        return False
        except Exception:
            pass
        # Fall back to basic UID
        result[0] = tag.identifier.hex().upper()
        return False

    try:
        with nfc.ContactlessFrontend("usb") as clf:
            clf.connect(rdwr={"on-connect": on_connect},
                        terminate=lambda: result[0] is not None)
        return result[0]
    except Exception as e:
        log.error(f"ACR122U read error: {e}")
        return None

# ─── Keypad ───────────────────────────────────────────────────────────────────

KEYPAD_ROWS = cfg.get("keypad_rows", [5, 6, 13, 19])
KEYPAD_COLS = cfg.get("keypad_cols", [26, 16, 20, 21])
KEYPAD_KEYS = [
    ["1","2","3","A"],
    ["4","5","6","B"],
    ["7","8","9","C"],
    ["*","0","#","D"],
]

def init_keypad():
    if not USE_KEYPAD or not HAS_GPIO:
        return
    for row in KEYPAD_ROWS:
        GPIO.setup(row, GPIO.OUT, initial=GPIO.HIGH)
    for col in KEYPAD_COLS:
        GPIO.setup(col, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    log.info("Keypad initialized")

def scan_keypad():
    """Returns pressed key character, or None."""
    if not USE_KEYPAD or not HAS_GPIO:
        return None
    for r, row_pin in enumerate(KEYPAD_ROWS):
        GPIO.output(row_pin, GPIO.LOW)
        for c, col_pin in enumerate(KEYPAD_COLS):
            if GPIO.input(col_pin) == GPIO.LOW:
                GPIO.output(row_pin, GPIO.HIGH)
                time.sleep(0.05)
                return KEYPAD_KEYS[r][c]
        GPIO.output(row_pin, GPIO.HIGH)
    return None

pin_buffer = ""
pin_last_key_time = 0.0
pin_lock = threading.Lock()

def handle_keypad_input():
    """Called in loop — accumulates PIN, sends on # or timeout."""
    global pin_buffer, pin_last_key_time
    key = scan_keypad()
    if not key:
        # Check timeout
        if pin_buffer and (time.time() - pin_last_key_time) > PIN_TIMEOUT:
            with pin_lock:
                log.info(f"[PIN] Timeout — clearing buffer")
                pin_buffer = ""
        return

    now = time.time()
    with pin_lock:
        if key == "#":
            # Submit PIN
            if pin_buffer:
                pin = pin_buffer
                pin_buffer = ""
                threading.Thread(target=validate_and_respond, args=(f"PIN-{pin}",), daemon=True).start()
        elif key == "*":
            # Clear
            pin_buffer = ""
            flash_led(LED_RED, 0.1)
        elif key.isdigit():
            pin_buffer += key
            pin_last_key_time = now
            buzz(50)  # brief click feedback
            show_display(f"PIN: {'*' * len(pin_buffer)}")

# ─── OLED Display ─────────────────────────────────────────────────────────────

display = None

def init_display():
    global display
    if not USE_DISPLAY:
        return
    try:
        from luma.core.interface.serial import i2c
        from luma.oled.device import ssd1306
        serial = i2c(port=1, address=0x3C)
        display = ssd1306(serial)
        show_display("Amirani\nReady")
        log.info("OLED display initialized")
    except Exception as e:
        log.warning(f"Display init failed: {e}")

def show_display(text: str):
    if not display:
        return
    try:
        from luma.core.render import canvas
        from PIL import ImageFont
        with canvas(display) as draw:
            lines = text.split("\n")
            y = 0
            for line in lines:
                draw.text((0, y), line, fill="white")
                y += 16
    except Exception as e:
        log.warning(f"Display error: {e}")

# ─── Hardware Feedback ────────────────────────────────────────────────────────

def set_relay(state: bool):
    if HAS_GPIO:
        GPIO.output(RELAY_PIN, GPIO.HIGH if state else GPIO.LOW)

def flash_led(pin: int, duration: float):
    if HAS_GPIO:
        GPIO.output(pin, GPIO.HIGH)
        time.sleep(duration)
        GPIO.output(pin, GPIO.LOW)

def buzz(duration_ms: int):
    if HAS_GPIO:
        GPIO.output(BUZZER_PIN, GPIO.HIGH)
        time.sleep(duration_ms / 1000)
        GPIO.output(BUZZER_PIN, GPIO.LOW)

def feedback_granted(name: str):
    show_display(f"Welcome!\n{name[:16]}")
    threading.Thread(target=lambda: (
        GPIO.output(LED_GREEN, GPIO.HIGH) if HAS_GPIO else None,
        buzz(100), time.sleep(0.1), buzz(100),
        time.sleep(UNLOCK_MS / 1000),
        GPIO.output(LED_GREEN, GPIO.LOW) if HAS_GPIO else None,
        show_display("Amirani\nReady")
    ), daemon=True).start()

def feedback_denied(reason: str):
    show_display(f"Denied\n{reason[:16]}")
    threading.Thread(target=lambda: (
        GPIO.output(LED_RED, GPIO.HIGH) if HAS_GPIO else None,
        buzz(500),
        GPIO.output(LED_RED, GPIO.LOW) if HAS_GPIO else None,
        time.sleep(2),
        show_display("Amirani\nReady")
    ), daemon=True).start()

# ─── Door Unlock ──────────────────────────────────────────────────────────────

unlock_lock = threading.Lock()

def trigger_unlock(duration_ms: int = None):
    if duration_ms is None:
        duration_ms = UNLOCK_MS
    with unlock_lock:
        log.info(f"[RELAY] Unlocking for {duration_ms}ms")
        set_relay(True)
        time.sleep(duration_ms / 1000)
        set_relay(False)
        log.info("[RELAY] Locked")

# ─── Backend API ──────────────────────────────────────────────────────────────

SESSION = requests.Session()
SESSION.headers.update({"X-Gateway-Key": API_KEY, "Content-Type": "application/json"})

def validate_card(card_uid: str) -> dict:
    """Call backend to validate a card/PIN scan."""
    try:
        resp = SESSION.post(
            f"{BACKEND_URL}/api/hardware/gw/validate",
            json={"cardUid": card_uid},
            timeout=5
        )
        return resp.json().get("data", resp.json())
    except requests.exceptions.Timeout:
        log.error("[API] Timeout on validate")
        return {"granted": False, "reason": "Backend timeout"}
    except Exception as e:
        log.error(f"[API] Validate error: {e}")
        return {"granted": False, "reason": "Connection error"}

def send_heartbeat():
    """POST /hardware/gw/heartbeat every 30 seconds."""
    while True:
        try:
            SESSION.post(f"{BACKEND_URL}/api/hardware/gw/heartbeat", timeout=5)
        except Exception as e:
            log.warning(f"[Heartbeat] Failed: {e}")
        time.sleep(30)

def poll_commands():
    """REST fallback — polls pending commands when WebSocket is not connected."""
    while True:
        if not ws_connected:
            try:
                resp = SESSION.get(f"{BACKEND_URL}/api/hardware/gw/commands", timeout=5)
                commands = resp.json().get("data", [])
                for cmd in commands:
                    handle_command(cmd)
                    # ACK
                    SESSION.post(
                        f"{BACKEND_URL}/api/hardware/gw/commands/{cmd['id']}/ack",
                        json={"success": True}, timeout=5
                    )
            except Exception as e:
                log.warning(f"[Poll] Error: {e}")
        time.sleep(5)

def validate_and_respond(uid: str):
    """Validate a card/PIN and trigger relay + feedback."""
    log.info(f"[Scan] UID: {uid}")
    show_display("Checking...")
    result = validate_card(uid)
    if result.get("granted"):
        name = result.get("memberName", "Member")
        plan = result.get("planName", "")
        days = result.get("daysRemaining")
        log.info(f"[✓] GRANTED — {name} ({plan})" + (f" — {days}d left" if days else ""))
        feedback_granted(name)
        trigger_unlock()
    else:
        reason = result.get("reason", "Denied")
        log.info(f"[✗] DENIED — {reason}")
        feedback_denied(reason)

# ─── WebSocket ────────────────────────────────────────────────────────────────

sio = socketio.Client(reconnection=True, reconnection_delay=3)
ws_connected = False

def handle_command(cmd: dict):
    """Handle UNLOCK command from dashboard or WebSocket."""
    command = cmd.get("command")
    if command == "UNLOCK":
        duration = cmd.get("payload", {}).get("durationMs", UNLOCK_MS)
        log.info(f"[CMD] UNLOCK from dashboard (duration={duration}ms)")
        threading.Thread(target=trigger_unlock, args=(duration,), daemon=True).start()
        return True
    return False

@sio.event(namespace="/gateway")
def connect():
    global ws_connected
    ws_connected = True
    log.info("[WS] Connected to backend gateway namespace")
    show_display("Amirani\nConnected")

@sio.event(namespace="/gateway")
def disconnect():
    global ws_connected
    ws_connected = False
    log.warning("[WS] Disconnected — falling back to REST polling")

@sio.on("command", namespace="/gateway")
def on_command(data):
    success = handle_command(data)
    sio.emit("ack", {"commandId": data["id"], "success": success}, namespace="/gateway")

def connect_websocket():
    while True:
        try:
            log.info("[WS] Connecting...")
            sio.connect(
                BACKEND_URL,
                auth={"apiKey": API_KEY},
                namespaces=["/gateway"],
                transports=["websocket"]
            )
            sio.wait()
        except Exception as e:
            log.warning(f"[WS] Connection failed: {e} — retrying in 5s")
            time.sleep(5)

# ─── Main Loop ────────────────────────────────────────────────────────────────

def main():
    log.info("=" * 50)
    log.info("  Amirani Gateway Firmware starting...")
    log.info(f"  Backend: {BACKEND_URL}")
    log.info(f"  NFC:     {USE_NFC} ({NFC_READER})")
    log.info(f"  Keypad:  {USE_KEYPAD}")
    log.info(f"  Display: {USE_DISPLAY}")
    log.info("=" * 50)

    init_nfc()
    init_keypad()
    init_display()

    show_display("Amirani\nStarting...")

    # Background threads
    threading.Thread(target=send_heartbeat, daemon=True).start()
    threading.Thread(target=poll_commands, daemon=True).start()
    threading.Thread(target=connect_websocket, daemon=True).start()

    time.sleep(1)
    show_display("Amirani\nReady")
    log.info("[Ready] Waiting for card tap or PIN...")

    # ── Main scan loop ────────────────────────────────────────────────────────
    if USE_NFC and NFC_READER == "mfrc522":
        while True:
            try:
                uid = read_nfc_uid_mfrc522()
                if uid:
                    threading.Thread(target=validate_and_respond, args=(uid,), daemon=True).start()
                    time.sleep(1.5)  # debounce — prevent double-read
                if USE_KEYPAD:
                    handle_keypad_input()
            except KeyboardInterrupt:
                log.info("Shutdown requested")
                break
            except Exception as e:
                log.error(f"Main loop error: {e}")
                time.sleep(1)

    elif USE_NFC and NFC_READER == "acr122u":
        while True:
            try:
                uid = read_nfc_uid_acr122u()
                if uid:
                    threading.Thread(target=validate_and_respond, args=(uid,), daemon=True).start()
                if USE_KEYPAD:
                    handle_keypad_input()
            except KeyboardInterrupt:
                break
            except Exception as e:
                log.error(f"Main loop error: {e}")
                time.sleep(1)

    elif USE_KEYPAD:
        # Keypad-only mode (PIN)
        log.info("[Mode] Keypad-only (PIN entry)")
        while True:
            try:
                handle_keypad_input()
                time.sleep(0.05)
            except KeyboardInterrupt:
                break

    else:
        # WebSocket/REST-only mode (just "Open Door" button from dashboard)
        log.info("[Mode] Remote-only (dashboard Open Door button)")
        while True:
            time.sleep(1)

    if HAS_GPIO:
        GPIO.cleanup()
    log.info("Gateway stopped.")


if __name__ == "__main__":
    main()
