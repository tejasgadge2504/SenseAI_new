from flask import Blueprint, request, jsonify
import requests
import os
import json
from .formatjson import clean_json_output

maternal_bp = Blueprint('maternal', __name__)

API_URL = "https://api.featherless.ai/v1/chat/completions"
API_KEY = os.getenv("FEATHERLESS_API_KEY")  # set this in env

# # 🔧 Build prompt
# def build_prompt(data):
#     return f"""
# You are a rural healthcare AI assistant helping a Community Health Worker.

# Analyze the following maternal case for postpartum hemorrhage risk.

# Inputs:
# - Bleeding Level: {data.get('bleeding_level')}
# - Pulse: {data.get('pulse')}
# - Blood Pressure: {data.get('bp')}
# - Weakness: {data.get('weakness')}
# - Description: {data.get('description')}

# Instructions:
# 1. Estimate hemorrhage risk score (0-100)
# 2. Classify risk: LOW, MEDIUM, HIGH
# 3. Give clear recommendation
# 4. Provide simple explanation
# 5. Mention missing/uncertain data
# 6. Give step-by-step checklist
# 7. Give me the output in {data.get('language')} language

# Respond ONLY in JSON format:
# {{
#   "risk_score": int,
#   "risk_level": "LOW | MEDIUM | HIGH",
#   "recommendation": "...",
#   "confidence": float,
#   "explanation": "...",
#   "missing_data": [],
#   "checklist": []
# }}
# """

def build_prompt(data):
    return f"""
You are a rural healthcare AI assistant helping a Community Health Worker.

Analyze the following maternal case for postpartum hemorrhage risk.

Inputs:
- Bleeding Level: {data.get('bleeding_level')}
- Pulse: {data.get('pulse')}
- Blood Pressure: {data.get('bp')}
- Weakness: {data.get('weakness')}
- Description: {data.get('description')}

SCORING RULES (STRICT):
Assign risk score using these weights:

1. Bleeding:
- low = 10
- medium = 30
- heavy = 60

2. Pulse:
- < 100 → 5
- 100–120 → 15
- > 120 → 30

3. Blood Pressure:
- Normal (>=100 systolic) → 5
- Mild low (90–100) → 20
- Severe low (<90) → 40

4. Weakness:
- no → 5
- yes → 20

FINAL SCORE:
- Sum all values
- Cap between 0–100

RISK CLASSIFICATION:
- 0–30 → LOW
- 31–60 → MEDIUM
- 61–100 → HIGH

CONFIDENCE RULES:
- High confidence (0.8–1.0): all inputs present and clear
- Medium (0.5–0.8): minor missing data
- Low (0.2–0.5): multiple missing/unclear inputs

Instructions:
- DO NOT guess randomly
- Always follow scoring rules strictly
- Give explanation based on which factors increased risk
- Give checklist for CHW action
- Respond in {data.get('language')} language

Respond ONLY in JSON format:
{{
  "risk_score": int,
  "risk_level": "LOW | MEDIUM | HIGH",
  "recommendation": "...",
  "confidence": float,
  "explanation": "...",
  "missing_data": [],
  "checklist": []
}}
"""
# 🔁 Fallback logic (offline-safe backup)
def fallback_logic(data):
    if data.get("bleeding_level") == "heavy":
        return {
            "risk_score": 85,
            "risk_level": "HIGH",
            "recommendation": "Immediate referral required",
            "confidence": 0.6,
            "explanation": "Heavy bleeding detected",
            "missing_data": [],
            "checklist": [
                "Lay patient flat",
                "Elevate legs",
                "Arrange emergency transport"
            ]
        }
    return {
        "risk_score": 40,
        "risk_level": "MEDIUM",
        "recommendation": "Monitor patient closely",
        "confidence": 0.5,
        "explanation": "Limited data available",
        "missing_data": [],
        "checklist": ["Recheck vitals"]
    }

# 🚀 API Route
@maternal_bp.route('/diagnosis/maternal', methods=['POST'])
def maternal_diagnosis():
    try:
        data = request.get_json()

        # Basic validation
        if not data:
            return jsonify({"error": "No input data provided"}), 400

        prompt = build_prompt(data)

        # 🔥 API Call using requests
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

        # Extract model output
        output_text = result["choices"][0]["message"]["content"]

        # Parse JSON safely
        try:
            parsed_json, error = clean_json_output(output_text)

            if error:
                return jsonify({
                    "error": "Invalid JSON from model",
                    "details": error,
                    "raw_output": output_text
                }), 500

            return jsonify(parsed_json)
        except:
            return jsonify({
                "error": "Invalid JSON from model",
                "raw_output": output_text
            }), 500

    except Exception as e:
        print("⚠️ API failed, using fallback:", str(e))
        return jsonify(fallback_logic(data))