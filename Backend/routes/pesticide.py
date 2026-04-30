from flask import Blueprint, request, jsonify
import requests
import os
from .formatjson import clean_json_output

pesticide_bp = Blueprint('pesticide', __name__)

API_URL = "https://api.featherless.ai/v1/chat/completions"
API_KEY = os.getenv("FEATHERLESS_API_KEY")


# # 🔧 Prompt Builder
def build_prompt(data):
    return f"""
You are a rural healthcare AI assistant helping a Community Health Worker.

Analyze the following case for pesticide poisoning risk.

Inputs:
- Symptoms: {data.get('symptoms')}
- Crop Type: {data.get('crop_type')}
- Recent Exposure: {data.get('recent_exposure')}
- Duration: {data.get('duration')}
- Protective Gear Used: {data.get('protective_gear')}
- Description: {data.get('text_input')}

Context:
Different crops are associated with different pesticide types. Consider likely poisoning patterns.

Instructions:
1. Estimate poisoning probability score (0-100)
2. Classify risk: LOW, MEDIUM, HIGH, CRITICAL
3. Recommend immediate first-response actions
4. Identify if emergency referral is needed
5. Provide simple explanation
6. Mention missing/uncertain data
7. Give step-by-step checklist
8. Give me the output in {data.get('language')} language


SCORING:

Symptoms:
- vomiting → +25
- dizziness → +15
- headache → +10
- blurred vision → +20

Exposure:
- yes → +30
- no → +0

Protective Gear:
- no → +20
- yes → +5

Duration:
- >2 hrs → +20
- 30min–2hr → +10
- <30min → +5

FINAL SCORE capped 0–100

RISK:
- 0–30 LOW
- 31–60 MEDIUM
- 61–80 HIGH
- 81–100 CRITICAL

Emergency:
- If vomiting + exposure OR score >70 → emergency = true

CONFIDENCE:
- Based on completeness of symptoms + exposure info

Follow rules strictly. No guessing.


Respond ONLY in JSON format:
{{
  "risk_score": int,
  "risk_level": "LOW | MEDIUM | HIGH | CRITICAL",
  "poisoning_probability": int,
  "recommendation": "...",
  "emergency": true/false,
  "confidence": float,
  "explanation": "...",
  "missing_data": [],
  "checklist": []
}}
"""


# 🔁 Fallback Logic
def fallback_logic(data):
    symptoms = data.get("symptoms", [])
    exposure = data.get("recent_exposure", "no")

    if exposure == "yes" and ("vomiting" in symptoms or "dizziness" in symptoms):
        return {
            "risk_score": 80,
            "risk_level": "HIGH",
            "poisoning_probability": 85,
            "recommendation": "Possible pesticide poisoning. Provide first aid and refer immediately.",
            "emergency": True,
            "confidence": 0.6,
            "explanation": "Exposure with key symptoms like vomiting/dizziness detected",
            "missing_data": [],
            "checklist": [
                "Move patient to fresh air immediately",
                "Remove contaminated clothing",
                "Wash skin with clean water",
                "Do NOT induce vomiting",
                "Arrange urgent transport to hospital"
            ]
        }

    return {
        "risk_score": 40,
        "risk_level": "MEDIUM",
        "poisoning_probability": 50,
        "recommendation": "Monitor symptoms and avoid further exposure",
        "emergency": False,
        "confidence": 0.5,
        "explanation": "Limited symptoms detected",
        "missing_data": [],
        "checklist": [
            "Observe patient",
            "Ensure hydration",
            "Reassess if symptoms worsen"
        ]
    }


# 🚀 API Route
@pesticide_bp.route('/diagnosis/pesticide', methods=['POST'])
def pesticide_diagnosis():
    try:
        data = request.get_json()

        if not data:
            return jsonify({"error": "No input data provided"}), 400

        prompt = build_prompt(data)

        response = requests.post(
            url=API_URL,
            headers={
                "Authorization": f"Bearer {API_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "model": "deepseek-ai/DeepSeek-V3-0324",
                "messages": [
                    {"role": "system", "content": "You are a medical triage assistant."},
                    {"role": "user", "content": prompt}
                ],
                "temperature": 0.2
            },
            timeout=10
        )

        result = response.json()

        output_text = result["choices"][0]["message"]["content"]

        parsed_json, error = clean_json_output(output_text)

        if error:
            print("⚠️ JSON parsing failed, using fallback")
            return jsonify(fallback_logic(data))

        return jsonify(parsed_json)

    except Exception as e:
        print("⚠️ API failed, using fallback:", str(e))
        return jsonify(fallback_logic(data))