from flask import Blueprint, request, jsonify
import os
import base64
import requests
from .formatjson import clean_json_output

dfu_bp = Blueprint('dfu', __name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key={GEMINI_API_KEY}"


# 🔧 Convert image to base64
def encode_image(file):
    return base64.b64encode(file.read()).decode('utf-8')


# # 🔧 Prompt Builder
def build_prompt(data):
    return f"""
You are a rural healthcare AI assistant helping a Community Health Worker.

Analyze this foot image for diabetic foot ulcer severity and infection risk.

Additional Inputs:
- Pain: {data.get('pain')}
- Swelling: {data.get('swelling')}
- Duration: {data.get('duration')}

Instructions:
1. Estimate risk score (0-100)
2. Classify risk: LOW, MEDIUM, HIGH, CRITICAL
3. Classify ulcer severity: Mild, Moderate, Severe
4. Detect infection risk
5. Give recommendation
6. Provide simple explanation
7. Mention missing data
8. Give checklist
9. Give me the output in {data.get('language')} language

IMAGE ANALYSIS RULES:

Evaluate:
1. Wound size
2. Depth
3. Infection signs:
   - redness
   - pus
   - black tissue (necrosis)

SCORING:

Pain:
- low → 5
- moderate → 15
- high → 25

Swelling:
- no → 5
- yes → 20

Duration:
- <3 days → 5
- 3–7 days → 15
- >7 days → 30

Image severity:
- minor cuts → 10
- open wound → 30
- deep/infected → 50

FINAL SCORE capped 100

RISK:
- 0–30 LOW
- 31–60 MEDIUM
- 61–80 HIGH
- 81–100 CRITICAL

STRICT CONDITION:
- DO NOT classify HIGH unless:
  - deep wound OR infection signs present

CONFIDENCE:
- High if image + inputs match clearly
- Low if image unclear

IMPORTANT:
- Small tear = LOW or MEDIUM only
- Never exaggerate severity

Respond ONLY in JSON format:
{{
  "risk_score": int,
  "risk_level": "LOW | MEDIUM | HIGH | CRITICAL",
  "ulcer_severity": "Mild | Moderate | Severe",
  "infection_risk": "LOW | MEDIUM | HIGH",
  "recommendation": "...",
  "confidence": float,
  "explanation": "...",
  "missing_data": [],
  "checklist": []
}}
"""

# 🔁 Fallback
def fallback_logic():
    return {
        "risk_score": 50,
        "risk_level": "MEDIUM",
        "ulcer_severity": "Moderate",
        "infection_risk": "MEDIUM",
        "recommendation": "Clean wound and monitor. Refer if worsening.",
        "confidence": 0.5,
        "explanation": "Unable to analyze image clearly",
        "missing_data": ["Clear image"],
        "checklist": [
            "Clean wound daily",
            "Apply antiseptic",
            "Avoid pressure on foot"
        ]
    }


# 🚀 API
@dfu_bp.route('/diagnosis/dfu', methods=['POST'])
def dfu_diagnosis():
    try:
        if 'image' not in request.files:
            return jsonify({"error": "No image provided"}), 400

        file = request.files['image']
        image_base64 = encode_image(file)

        data = request.form
        prompt = build_prompt(data)

        # 🔥 Gemini API Call
        response = requests.post(
            GEMINI_URL,
            headers={
                "Content-Type": "application/json"
            },
            json={
                "contents": [
                    {
                        "parts": [
                            {"text": prompt},
                            {
                                "inline_data": {
                                    "mime_type": "image/jpeg",
                                    "data": image_base64
                                }
                            }
                        ]
                    }
                ]
            },
            timeout=15
        )

        result = response.json()

        # Extract Gemini response
        output_text = result["candidates"][0]["content"]["parts"][0]["text"]

        parsed_json, error = clean_json_output(output_text)

        if error:
            print("⚠️ JSON parsing failed, using fallback")
            return jsonify(fallback_logic())

        return jsonify(parsed_json)

    except Exception as e:
        print("⚠️ DFU failed:", str(e))
        return jsonify(fallback_logic())