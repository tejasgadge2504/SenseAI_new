from flask import Blueprint, request, jsonify
import requests
import os
from .formatjson import clean_json_output

chw_bp = Blueprint('chw', __name__)

API_URL = "https://api.featherless.ai/v1/chat/completions"
API_KEY = os.getenv("FEATHERLESS_API_KEY")


# 🔧 Prompt Builder
def build_prompt(data):
    return f"""
You are a healthcare assistant helping a rural Community Health Worker (CHW).

Your job is to simplify and summarize medical AI outputs.

Patient Info:
{data.get("patient_info")}

Agent Outputs:
{data.get("agent_outputs")}

Instructions:
1. Summarize key risks in simple language
2. Prioritize urgency (LOW, MEDIUM, HIGH, CRITICAL)
3. Combine all recommendations into one clear plan
4. Provide step-by-step actions
5. Explain reasoning in simple non-medical terms
6. Suggest next follow-up tasks
7. Give me the output in {data.get('language')} language

Respond ONLY in JSON format:

{{
  "final_risk_level": "LOW | MEDIUM | HIGH | CRITICAL",
  "summary": "...",
  "action_plan": "...",
  "priority_actions": [],
  "explanation": "...",
  "next_steps": [],
  "confidence": float
}}
"""


# 🔁 Fallback
def fallback_logic():
    return {
        "final_risk_level": "MEDIUM",
        "summary": "Patient needs monitoring",
        "action_plan": "Follow standard procedures",
        "priority_actions": ["Check vitals", "Follow up"],
        "explanation": "Limited data available",
        "next_steps": ["Reassess patient"],
        "confidence": 0.5
    }


# 🚀 API
@chw_bp.route('/support/chw', methods=['POST'])
def chw_support():
    try:
        data = request.get_json()

        if not data:
            return jsonify({"error": "No data provided"}), 400

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
                    {"role": "system", "content": "You are a helpful rural health assistant."},
                    {"role": "user", "content": prompt}
                ],
                "temperature": 0.2
            }
        )

        result = response.json()

        output_text = result["choices"][0]["message"]["content"]

        parsed_json, error = clean_json_output(output_text)

        if error:
            print("⚠️ JSON parsing failed, using fallback")
            return jsonify(fallback_logic())

        return jsonify(parsed_json)

    except Exception as e:
        print("⚠️ CHW agent failed:", str(e))
        return jsonify(fallback_logic())