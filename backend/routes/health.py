import os
import requests
from enum import Enum
from fastapi import APIRouter
from dotenv import load_dotenv
from pydantic import BaseModel

load_dotenv()

router = APIRouter()


class Status(str, Enum):
    HEALTHY = "healthy"
    UNHEALTHY = "unhealthy"


class HealthResponse(BaseModel):
    llm_provider: Status
    api_status: Status
    status: Status


def _get_llm_provider_status() -> Status:
    """Check if the configured LLM provider is accessible."""
    llm_provider = os.getenv("LLM_PROVIDER")

    if llm_provider == "lm_studio":
        api_url = os.getenv("LM_STUDIO_SERVER_URL")
        api_port = os.getenv("LM_STUDIO_SERVER_PORT")
        endpoint = f"{api_url}:{api_port}/v1/models"
    elif llm_provider == "ollama":
        api_url = os.getenv("OLLAMA_SERVER_URL")
        api_port = os.getenv("OLLAMA_SERVER_PORT")
        endpoint = f"{api_url}:{api_port}/api/tags"
    else:
        return Status.UNHEALTHY

    try:
        response = requests.get(endpoint, timeout=5)
        return Status.HEALTHY if response.status_code == 200 else Status.UNHEALTHY
    except requests.exceptions.RequestException:
        return Status.UNHEALTHY


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    """
    Health check endpoint that verifies the LLM server is running.
    Returns:
    - llm_provider: healthy/unhealthy based on server connectivity
    - api_status: always healthy, because if this endpoint is reachable, the API is healthy
    - status: healthy if llm_provider is healthy, unhealthy otherwise
    """
    llm_provider_status = _get_llm_provider_status()
    api_status = Status.HEALTHY
    overall_status = llm_provider_status  # Status is unhealthy only if LLM provider is unhealthy as if the request can be sent back this means the API is healthy

    return HealthResponse(
        llm_provider=llm_provider_status,
        api_status=api_status,
        status=overall_status
    )

