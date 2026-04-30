import json
import re

def clean_json_output(raw_text):
    """
    Cleans LLM output and extracts valid JSON.
    Handles cases like ```json ... ```
    """

    if not raw_text:
        return None, "Empty response"

    try:
        # 🔹 Remove markdown code blocks (```json ... ```)
        cleaned = re.sub(r"```json|```", "", raw_text).strip()

        # 🔹 Extract JSON object using regex
        match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if not match:
            return None, "No JSON object found"

        json_str = match.group(0)

        # 🔹 Load JSON
        parsed = json.loads(json_str)

        return parsed, None

    except Exception as e:
        return None, str(e)