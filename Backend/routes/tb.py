from flask import Blueprint, request, jsonify
import requests
import os
from .formatjson import clean_json_output

tb_bp = Blueprint('tb', __name__)

API_URL = "https://api.featherless.ai/v1/chat/completions"
API_KEY = os.getenv("FEATHERLESS_API_KEY")


# # 🔧 Prompt Builder
def build_prompt(data):
    return f"""
You are a rural healthcare AI assistant helping a Community Health Worker.

Analyze the following TB patient for adherence risk and relapse probability.

Inputs:
- Missed Doses: {data.get('missed_doses')}
- Days Since Last Dose: {data.get('days_since_last_dose')}
- Symptoms: {data.get('symptoms')}
- Weight Loss: {data.get('weight_loss')}
- Appetite Loss: {data.get('appetite_loss')}
- Duration of Symptoms: {data.get('duration_of_symptoms')}
- Past Summary: {data.get('past_summary')}
- Age: {data.get('age')}

Instructions:
1. Estimate adherence risk score (0-100)
2. Classify risk: LOW, MEDIUM, HIGH
3. Detect possible relapse
4. Recommend action for CHW
5. Provide simple explanation
6. Mention missing/uncertain data
7. Give step-by-step checklist
8. Give me the output in {data.get('language')} language


SCORING:

Missed doses:
- 0 → 5
- 1–3 → 20
- >3 → 40

Days since last dose:
- <3 → 5
- 3–7 → 20
- >7 → 35

Symptoms:
(each adds)
- cough → 10
- fever → 10
- night_sweats → 15
- fatigue → 10

Weight loss:
- yes → +15

Appetite loss:
- yes → +10

FINAL SCORE capped 100

RISK:
- LOW <30
- MEDIUM 30–60
- HIGH >60

Relapse:
- HIGH if missed_doses >3 AND symptoms present

CONFIDENCE:
- Based on symptom completeness

STRICT RULE:
Never randomly assign score.

Respond ONLY in JSON format:
{{
  "risk_score": int,
  "risk_level": "LOW | MEDIUM | HIGH",
  "relapse_risk": "LOW | MEDIUM | HIGH",
  "recommendation": "...",
  "confidence": float,
  "explanation": "...",
  "missing_data": [],
  "checklist": []
}}
"""



# 🔁 Fallback Logic (Offline-safe)
def fallback_logic(data):
    missed = data.get("missed_doses", 0)
    symptoms = data.get("symptoms", [])

    if missed >= 3 or "cough" in symptoms:
        return {
            "risk_score": 75,
            "risk_level": "HIGH",
            "relapse_risk": "HIGH",
            "recommendation": "Immediate follow-up required. Ensure medication adherence.",
            "confidence": 0.6,
            "explanation": "Missed doses and symptoms indicate possible relapse",
            "missing_data": [],
            "checklist": [
                "Visit patient immediately",
                "Counsel on adherence",
                "Check sputum test if available",
                "Ensure medication supply"
            ]
        }

    return {
        "risk_score": 40,
        "risk_level": "MEDIUM",
        "relapse_risk": "LOW",
        "recommendation": "Monitor adherence",
        "confidence": 0.5,
        "explanation": "Partial adherence detected",
        "missing_data": [],
        "checklist": [
            "Remind patient to take medicines",
            "Schedule follow-up visit"
        ]
    }


# 🚀 API Route
@tb_bp.route('/diagnosis/tb', methods=['POST'])
def tb_diagnosis():
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