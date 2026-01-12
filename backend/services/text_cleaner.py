import requests
import os
from dotenv import load_dotenv

load_dotenv()

llm_provider = os.getenv("LLM_PROVIDER")
llm_model_name = os.getenv("LLM_MODEL_NAME")

# Define the system prompt for disfluency removal, not recommended to modify
system_prompt = (
    "You are a text normalization system for spoken transcripts. "
    "Your task is disfluency removal only. "
    "Remove filler words (e.g., 'uh', 'um', 'like'), false starts, repetitions, "
    "and self-corrections while preserving the original meaning, intent, and tone. "
    "Do not summarize or paraphrase unless required to remove a disfluency. "
    "Do not add or infer new information. "
    "Preserve punctuation, capitalization, technical terms, acronyms, "
    "and domain-specific language."
    "Output only the cleaned transcript without any additional commentary or explanations."
)


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
    else:
        raise ValueError(f"Unsupported LLM provider: {llm_provider}")

    try:
        payload = {
            "model": llm_model_name,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": text}
            ],
            "temperature": 0.3,
            "max_tokens": 2000
        }

        print(f"[LLM] Calling endpoint: {endpoint}")
        print(f"[LLM] Model: {llm_model_name}")
        print(f"[LLM] Input length: {len(text)} chars")

        # Increased timeout to 180 seconds to allow for model loading and processing
        response = requests.post(endpoint, json=payload, timeout=180)
        response.raise_for_status()

        result = response.json()
        print(f"[LLM] Response received: {result}")

        if llm_provider == "lm_studio":
            cleaned_text = result["choices"][0]["message"]["content"]
        elif llm_provider == "ollama":
            cleaned_text = result["message"]["content"]
        else:
            raise ValueError(f"Unsupported LLM provider: {llm_provider}")

        # Handle empty responses from LLM
        if not cleaned_text or cleaned_text.strip() == "":
            print("[LLM] Warning: Received empty response, returning original text")
            return text

        print(f"[LLM] Success! Output length: {len(cleaned_text)} chars")
        return cleaned_text.strip()

    except requests.exceptions.RequestException as e:
        print(f"[LLM] Request error: {str(e)}")
        raise Exception(f"Error calling LLM API: {str(e)}")
    except (KeyError, IndexError) as e:
        print(f"[LLM] Parsing error: {str(e)}")
        raise Exception(f"Error parsing LLM response: {str(e)}")


