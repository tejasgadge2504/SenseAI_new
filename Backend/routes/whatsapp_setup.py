from flask import Blueprint, request, jsonify
import requests
import os

whatsapp_bp_new = Blueprint('whatsapp', __name__)

VERIFY_TOKEN = "chembur"
WHATSAPP_TOKEN = os.getenv("WHATSAPP_TOKEN")

# 🧠 Temporary memory (use DB later)
user_sessions = {}

# ================= VERIFY =================
@whatsapp_bp_new.route('/webhook', methods=['GET'])
def verify():
    token = request.args.get("hub.verify_token")
    challenge = request.args.get("hub.challenge")

    if token == VERIFY_TOKEN:
        return challenge
    return "Verification failed"


# ================= RECEIVE =================
@whatsapp_bp_new.route('/webhook', methods=['POST'])
def receive_message():
    data = request.get_json()

    try:
        value = data['entry'][0]['changes'][0]['value']

        # ✅ Ignore non-message events (delivery, status)
        if 'messages' not in value:
            return jsonify({"status": "ignored"})

        message = value['messages'][0]
        phone = message['from']

        # ================= HANDLE MESSAGE TYPES =================
        msg_type = message.get("type")

        # 🔹 TEXT MESSAGE
        if msg_type == "text":
            text = message['text']['body'].lower()

            # send_message(phone, "🧠 Analyzing patient condition...\nPlease wait...")

            response = handle_flow(phone, text)
            send_message(phone, response)

        # 🔹 IMAGE (DFU)
        elif msg_type == "image":
            media_id = message["image"]["id"]

            send_message(phone, "🧠 Analyzing foot image...\nPlease wait...")

            # ✅ GET SESSION HERE
            session = user_sessions.get(phone, {})

            media_url = get_media_url(media_id)
            image_bytes = download_media(media_url)

            # Save temp image
            with open("temp.jpg", "wb") as f:
                f.write(image_bytes)

            # ✅ PASS LANGUAGE SAFELY
            result = call_dfu_api("temp.jpg", session.get("language", "english"))

            # ✅ CLEAR SESSION AFTER USE (optional but better)
            user_sessions.pop(phone, None)

            send_message(phone, format_response(result))

        else:
            send_message(phone, "⚠️ Unsupported message type. Please send text or image.")

    except Exception as e:
        print("❌ Error:", e)

    return jsonify({"status": "ok"})


# ================= FLOW =================
def normalize_language(lang):
    lang = lang.lower()

    if "marathi" in lang or "मराठी" in lang:
        return "marathi"
    elif "hindi" in lang or "हिंदी" in lang:
        return "hindi"
    return "english"


def handle_flow(phone, text):
    session = user_sessions.get(phone, {"step": "start"})

    # STEP 1: Start
    if text == "hi" or session["step"] == "start":
        user_sessions[phone] = {"step": "ask_name"}
        return "👋 Hello! What is your name?"

    # STEP 2: Name
    elif session["step"] == "ask_name":
        session["name"] = text
        session["step"] = "ask_age"
        user_sessions[phone] = session
        return "Enter your age:"

    # STEP 3: Age
    elif session["step"] == "ask_age":
        session["age"] = text
        session["step"] = "ask_language"
        user_sessions[phone] = session
        return "🌐 Preferred language? (English / Hindi / Marathi)"

    # STEP 4: Language
    elif session["step"] == "ask_language":
        session["language"] = normalize_language(text)
        session["step"] = "choose_condition"
        user_sessions[phone] = session

        return """Select condition:
1️⃣ Maternal
2️⃣ TB
3️⃣ Pesticide Exposure
4️⃣ Diabetic Foot Ulcer"""

    # STEP 5: Condition Selection
    elif session["step"] == "choose_condition":

        if text == "1":
            session["condition"] = "maternal"
            session["step"] = "maternal_bleeding"
            user_sessions[phone] = session
            return "Bleeding level? (low / medium / heavy)"

        elif text == "2":
            session["condition"] = "tb"
            session["step"] = "tb_missed"
            user_sessions[phone] = session
            return "Missed doses? (yes/no)"

        elif text == "3":
            session["condition"] = "pesticide"
            session["step"] = "pesticide_symptoms"
            user_sessions[phone] = session
            return "Symptoms? (vomiting/dizziness)"

        elif text == "4":
            session["condition"] = "dfu"
            user_sessions[phone] = session
            return "📸 Please upload foot image"

    # ================= MATERNAL =================
    elif session.get("condition") == "maternal":

        if session["step"] == "maternal_bleeding":
            session["bleeding"] = text
            session["step"] = "maternal_pulse"
            user_sessions[phone] = session
            return "Enter pulse:"

        elif session["step"] == "maternal_pulse":
            session["pulse"] = text
            session["step"] = "maternal_bp"
            user_sessions[phone] = session
            return "Enter BP (e.g., 120/80):"

        elif session["step"] == "maternal_bp":
            session["bp"] = text
            session["step"] = "maternal_weakness"
            user_sessions[phone] = session
            return "Weakness? (yes/no)"

        elif session["step"] == "maternal_weakness":
            session["weakness"] = text

            result = call_maternal_api(session)

            user_sessions.pop(phone)
            return format_response(result)

    # ================= TB =================
    elif session.get("condition") == "tb":

        if session["step"] == "tb_missed":
            session["missed"] = text

            result = call_tb_api(session)

            user_sessions.pop(phone)
            return format_response(result)

    # ================= PESTICIDE =================
    elif session.get("condition") == "pesticide":

        if session["step"] == "pesticide_symptoms":
            session["symptoms"] = text

            result = call_pesticide_api(session)

            user_sessions.pop(phone)
            return format_response(result)

    # ================= DFU =================
    elif session.get("condition") == "dfu":
        return "📸 Please upload foot image"

    return "Please type 'Hi' to start again."

# ================= MEDIA HANDLING =================
def get_media_url(media_id):
    url = f"https://graph.facebook.com/v18.0/{media_id}"

    headers = {
        "Authorization": f"Bearer {WHATSAPP_TOKEN}"
    }

    res = requests.get(url, headers=headers)
    return res.json().get("url")


def download_media(media_url):
    headers = {
        "Authorization": f"Bearer {WHATSAPP_TOKEN}"
    }

    res = requests.get(media_url, headers=headers)
    return res.content


# ================= API CALLS =================
def call_maternal_api(data):
    res = requests.post("http://localhost:5000/diagnosis/maternal", json={
        "bleeding_level": data["bleeding"],
        "pulse": data["pulse"],
        "bp": data["bp"],
        "weakness": data["weakness"],
        "description": "via whatsapp",
        "language": data.get("language", "english")
    })
    return res.json()


def call_tb_api(data):
    res = requests.post("http://localhost:5000/diagnosis/tb", json={
        "missed_doses": data["missed"],
        "symptoms": "",
        "weight_loss": "",
        "past_history": "",
        "language": data.get("language", "english")
    })
    return res.json()


def call_pesticide_api(data):
    res = requests.post("http://localhost:5000/diagnosis/pesticide", json={
        "symptoms": data["symptoms"],
        "crop_type": "",
        "exposure": "yes",
        "description": "",
        "language": data.get("language", "english")
    })
    return res.json()


def call_dfu_api(image_path,language="english"):
    files = {
        "image": open(image_path, "rb")
    }

    data = {
        "pain": "unknown",
        "swelling": "unknown",
        "duration": "unknown",
        "language": language
    }

    res = requests.post("http://localhost:5000/diagnosis/dfu", files=files, data=data)
    return res.json()


# ================= SEND MESSAGE =================
def send_message(phone, text):
    url = "https://graph.facebook.com/v18.0/1095012517027336/messages"

    headers = {
        "Authorization": f"Bearer {WHATSAPP_TOKEN}",
        "Content-Type": "application/json"
    }

    data = {
        "messaging_product": "whatsapp",
        "to": phone,
        "text": {"body": text}
    }

    requests.post(url, headers=headers, json=data)


# ================= FORMAT RESPONSE =================
def format_response(res):
    return f"""
🚨 Risk: {res.get('risk_level')}

📊 Score: {res.get('risk_score')}

📝 {res.get('recommendation')}

📌 Steps:
- """ + "\n- ".join(res.get("checklist", []))