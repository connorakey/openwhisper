import os

import requests
from dotenv import load_dotenv

load_dotenv()

llm_provider = os.getenv("LLM_PROVIDER")
llm_model_name = os.getenv("LLM_MODEL_NAME")
cloud_api_base_url = os.getenv("CLOUD_API_BASE_URL")
cloud_api_key = os.getenv("CLOUD_API_KEY")

# Define the system prompt for disfluency removal, not recommended to modify
system_prompt = """You are a transcript cleaning system that removes disfluencies from spoken text.

Your task:
1. Remove filler words: "uh", "um", "like", "ahh", etc.
2. Remove false starts and self-corrections - keep ONLY the final intended statement
3. Remove phrases like "actually", "wait no", "scratch that", "I meant" when they signal corrections
4. Preserve all technical terms EXACTLY as spoken (npm, PostgreSQL, React, Socket.io, etc.)
5. Preserve the speaker's final intent and meaning

Examples:
Input: "I want to use Docker and Kubernetes. Actually no, just Docker."
Output: "I want to use Docker."

Input: "Let's use MongoDB. Let's use Postgres instead."
Output: "Let's use Postgres."

Input: "I want WebSockets. Wait no, I meant Socket.io and Redis."
Output: "I want Socket.io and Redis."

Input: "We need npm packages like React, Next.js, and Tailwind CSS."
Output: "We need npm packages like React, Next.js, and Tailwind CSS."

Critical rules:
- When someone changes their mind ("actually no", "instead", "wait no"), ONLY keep the final decision
- Do NOT keep both the old and new choices
- Technical terms are sacred - never change them
- Output ONLY the cleaned text, no explanations

Clean this transcript:"""


def remove_disfluencies(text):
    """Sends the input text to an external AI model for disfluency removal."""
    if llm_provider == "lm_studio":
        api_url = os.getenv("LM_STUDIO_SERVER_URL")
        api_port = os.getenv("LM_STUDIO_SERVER_PORT")
        endpoint = f"{api_url}:{api_port}/v1/chat/completions"
    elif llm_provider == "ollama":
        api_url = os.getenv("OLLAMA_SERVER_URL")
        api_port = os.getenv("OLLAMA_SERVER_PORT")
        endpoint = f"{api_url}:{api_port}/api/chat"
    elif llm_provider == "cloud":
        # Ensure base URL ends with /chat/completions for OpenAI-compatible APIs
        base_url = cloud_api_base_url.rstrip("/")
        if not base_url.endswith("/chat/completions"):
            endpoint = f"{base_url}/chat/completions"
        else:
            endpoint = base_url
    else:
        raise ValueError(f"Unsupported LLM provider: {llm_provider}")

    try:
        payload = {
            "model": llm_model_name,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": text},
            ],
            "temperature": 0.3,
            "max_tokens": 2000,
        }

        headers = {}
        if llm_provider == "cloud":
            if not cloud_api_key:
                raise ValueError("CLOUD_API_KEY must be set when using cloud provider")
            headers["Authorization"] = f"Bearer {cloud_api_key}"
            headers["Content-Type"] = "application/json"

        response = requests.post(endpoint, json=payload, headers=headers, timeout=180)
        response.raise_for_status()

        result = response.json()

        if llm_provider == "lm_studio" or llm_provider == "cloud":
            cleaned_text = result["choices"][0]["message"]["content"]
        elif llm_provider == "ollama":
            cleaned_text = result["message"]["content"]
        else:
            raise ValueError(f"Unsupported LLM provider: {llm_provider}")

        # Handle empty responses from LLM
        if not cleaned_text or cleaned_text.strip() == "":
            return text

        return cleaned_text.strip()

    except requests.exceptions.RequestException as e:
        raise Exception(f"Error calling LLM API: {str(e)}")
    except (KeyError, IndexError) as e:
        raise Exception(f"Error parsing LLM response: {str(e)}")


