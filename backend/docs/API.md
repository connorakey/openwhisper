# OpenWhisper Backend API Documentation

## Overview

OpenWhisper is a free and open-source alternative to Whisperflow for Apple Silicon devices. The backend API provides endpoints for audio transcription with text normalization powered by local LLM providers.

**Base URL:** `http://localhost:8000`

**API Version:** 1.0.0

**Last Updated:** January 2026

---

## Table of Contents

- [Authentication](#authentication)
- [API Endpoints](#api-endpoints)
  - [Health Check](#health-check)
  - [Transcribe Audio](#transcribe-audio)
- [Request/Response Models](#requestresponse-models)
- [Status Codes](#status-codes)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)
- [Best Practices](#best-practices)
- [Code Examples](#code-examples)
- [FAQ](#faq)

---

## Authentication

All requests to the OpenWhisper API (except `/health`) require authorization using a Bearer token passed in the `Authorization` header.

### Generating an Authorization Token

Generate a secure token using OpenSSL:

```bash
openssl rand -hex 32
```

Example output:
```
a3f7b9c2d1e8f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8
```

### Adding the Token to Your `.env` File

```dotenv
API_AUTH_TOKEN=a3f7b9c2d1e8f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8
```

### Using the Token in Requests

Include the token in the `Authorization` header:

```bash
curl -H "Authorization: a3f7b9c2d1e8f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8" \
     http://localhost:8000/transcribe
```

---

## API Endpoints

### Health Check

Check the overall health status of the API and connected LLM provider.

**Endpoint:** `GET /health`

**Authentication:** Not required

**Description:** Returns the health status of the API, LLM provider, and overall system status.

#### Request

```bash
curl -X GET http://localhost:8000/health
```

#### Response

**Status Code:** `200 OK`

```json
{
  "llm_provider": "healthy",
  "api_status": "healthy",
  "status": "healthy"
}
```

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `llm_provider` | string | Status of the configured LLM provider (`healthy` or `unhealthy`) |
| `api_status` | string | Status of the API itself (always `healthy` if endpoint is reachable) |
| `status` | string | Overall system status (`healthy` if all components are working, `unhealthy` otherwise) |

#### Status Values

- **`healthy`** - Service is operational and responsive
- **`unhealthy`** - Service is not responding or has encountered an error

#### Example Response - Unhealthy LLM Provider

```json
{
  "llm_provider": "unhealthy",
  "api_status": "healthy",
  "status": "unhealthy"
}
```

**Possible Causes:**
- LLM server (Ollama/LM Studio) is not running
- Network connectivity issue
- Incorrect server URL/port configuration

---

### Transcribe Audio

Transcribe audio from base64-encoded data and apply text normalization.

**Endpoint:** `POST /transcribe`

**Authentication:** Required (Bearer token)

**Description:** Transcribes base64-encoded audio using Whisper, and normalizes the output using the configured LLM provider. You must encode the audio to base64 before sending it to this endpoint.

#### Request

```bash
curl -X POST http://localhost:8000/transcribe \
  -H "Content-Type: application/json" \
  -H "Authorization: your_auth_token_here" \
  -d '{"audio_base64":"SUQzBAAAAAAAI1RTU0UAAAAPAAADTGF2ZjU4LjI5LjEwMAAAAAAAAAAAAAAA//tQAAAAA..."}'
```

#### Request Body

```json
{
  "audio_base64": "string"
}
```

**Parameters:**

| Field | Type | Required | Description | Max Size |
|-------|------|----------|-------------|----------|
| `audio_base64` | string | Yes | Audio file encoded as base64 | 100 MB (base64 encoded) |

#### Supported Audio Formats

The API supports any audio format that Whisper can process:

- MP3
- WAV
- M4A
- OGG
- FLAC
- AAC

#### Response

**Status Code:** `200 OK`

```json
{
  "transcript": "Testing the transcription system."
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `transcript` | string | Normalized transcription text with disfluencies removed |

#### Error Response Examples

**Missing Authorization:**
```json
{
  "detail": "Unauthorized: Invalid or missing authorization token"
}
```
**Status Code:** `401 Unauthorized`

**Invalid Request:**
```json
{
  "detail": "Field required: 'audio_base64'"
}
```
**Status Code:** `422 Unprocessable Entity`

**Server Error:**
```json
{
  "detail": "Error calling LLM API: Connection timeout"
}
```
**Status Code:** `500 Internal Server Error`

#### How to Encode Audio to Base64

**Using Python:**
```python
import base64

with open("audio.mp3", "rb") as audio_file:
    audio_base64 = base64.b64encode(audio_file.read()).decode("utf-8")
    print(audio_base64)
```

**Using bash:**
```bash
base64 -i audio.mp3 -o audio_base64.txt
cat audio_base64.txt
```

**Using jq (from file):**
```bash
curl -X POST http://localhost:8000/transcribe \
  -H "Content-Type: application/json" \
  -H "Authorization: your_token" \
  -d @<(jq -n --rawfile audio <(base64 audio.mp3) '{audio_base64: $audio}')
```

---

## Request/Response Models

### TranscribeRequest

```typescript
interface TranscribeRequest {
  audio_base64: string;  // Base64-encoded audio file
}
```

### TranscribeResponse

```typescript
interface TranscribeResponse {
  transcript: string;  // Normalized transcription
}
```

### HealthResponse

```typescript
interface HealthResponse {
  llm_provider: "healthy" | "unhealthy";
  api_status: "healthy" | "unhealthy";
  status: "healthy" | "unhealthy";
}
```

---

## Status Codes

| Code | Status | Description |
|------|--------|-------------|
| `200` | OK | Request successful |
| `401` | Unauthorized | Missing or invalid authorization token |
| `422` | Unprocessable Entity | Invalid request body or missing required fields |
| `500` | Internal Server Error | Server error (LLM API failure, transcription error, etc.) |
| `503` | Service Unavailable | API is starting up or under maintenance |

---

## Error Handling

### Common Error Scenarios

#### 1. LLM Provider Timeout
```json
{
  "detail": "Error calling LLM API: Read timed out. (read timeout=30)"
}
```

**Solution:**
- Ensure the LLM server is running
- Check network connectivity
- Verify the LLM_STUDIO_SERVER_URL or OLLAMA_SERVER_URL in `.env`
- Check the health endpoint first: `GET /health`

#### 2. Invalid Authorization Token
```json
{
  "detail": "Unauthorized: Invalid or missing authorization token"
}
```

**Solution:**
- Verify the Authorization header is present
- Ensure the token matches the `API_AUTH_TOKEN` in `.env`
- Generate a new token if needed: `openssl rand -hex 32`

#### 3. Audio File Too Large
```json
{
  "detail": "Error processing audio: File size exceeds maximum allowed size"
}
```

**Solution:**
- Compress the audio file before encoding
- Use a lower bitrate
- Split the audio into chunks

#### 4. Unsupported Audio Format
```json
{
  "detail": "Error: Unsupported audio format"
}
```

**Solution:**
- Convert the audio to a supported format (MP3, WAV, etc.)
- Use ffmpeg: `ffmpeg -i input.file -c:a libmp3lame -q:a 9 output.mp3`

---

## Rate Limiting

Currently, there is **no rate limiting** implemented. This may change in future versions based on deployment needs.

**Recommendations for production:**
- Implement rate limiting at the API gateway level
- Consider using a reverse proxy (nginx, Caddy) with rate limiting rules
- Monitor transcription queue to prevent resource exhaustion

---

## Best Practices

### 1. Error Handling
Always check the response status code and handle errors gracefully:

```python
import requests

response = requests.post(
    "http://localhost:8000/transcribe",
    json={"audio_base64": encoded_audio},
    headers={"Authorization": token},
    timeout=60
)

if response.status_code == 200:
    transcript = response.json()["transcript"]
elif response.status_code == 401:
    print("Invalid authorization token")
elif response.status_code == 500:
    print(f"Server error: {response.json()['detail']}")
else:
    print(f"Unexpected status: {response.status_code}")
```

### 2. Timeouts
Always set appropriate timeouts when making requests:

```python
# 60 seconds timeout for transcription (adjust based on your audio length)
response = requests.post(
    url,
    json=data,
    headers=headers,
    timeout=60
)
```

### 3. Health Checks
Perform health checks before making requests:

```python
def is_api_healthy():
    try:
        response = requests.get("http://localhost:8000/health", timeout=5)
        return response.status_code == 200
    except requests.RequestException:
        return False

if is_api_healthy():
    # Proceed with transcription
    pass
else:
    # Handle unavailable API
    pass
```

### 4. Secure Token Management
- **Never hardcode tokens** in your application code
- Use environment variables or secure vaults
- Rotate tokens periodically
- Use strong tokens (at least 32 bytes of entropy)

```python
import os
from dotenv import load_dotenv

load_dotenv()
api_token = os.getenv("API_AUTH_TOKEN")
```

### 5. Audio File Handling
- Validate file format before encoding
- Compress large files before sending
- Consider streaming for very large files
- Clean up temporary files after processing

```python
import os
from pathlib import Path

audio_file = Path("input.mp3")
if audio_file.stat().st_size > 50_000_000:  # 50 MB
    print("File is too large, consider compression")
```

### 6. Logging
Implement proper logging for debugging:

```python
import logging

logger = logging.getLogger(__name__)

try:
    response = requests.post(url, json=data, headers=headers, timeout=60)
    response.raise_for_status()
    logger.info(f"Transcription successful for {len(audio)} bytes")
except requests.RequestException as e:
    logger.error(f"Transcription failed: {e}")
```

---

## Code Examples

### Python

#### Basic Transcription

```python
import requests
import base64
import os
from dotenv import load_dotenv

load_dotenv()

API_URL = "http://localhost:8000"
API_TOKEN = os.getenv("API_AUTH_TOKEN")

def transcribe_audio(audio_path: str) -> str:
    """Transcribe an audio file."""
    
    # Read and encode audio file
    with open(audio_path, "rb") as f:
        audio_base64 = base64.b64encode(f.read()).decode("utf-8")
    
    # Make API request
    response = requests.post(
        f"{API_URL}/transcribe",
        json={"audio_base64": audio_base64},
        headers={"Authorization": API_TOKEN},
        timeout=60
    )
    
    # Handle response
    if response.status_code == 200:
        return response.json()["transcript"]
    else:
        raise Exception(f"API Error: {response.json()['detail']}")

# Usage
if __name__ == "__main__":
    transcript = transcribe_audio("audio.mp3")
    print(f"Transcript: {transcript}")
```

#### With Health Check

```python
import requests
import base64
import os
from dotenv import load_dotenv

load_dotenv()

API_URL = "http://localhost:8000"
API_TOKEN = os.getenv("API_AUTH_TOKEN")

def check_health() -> bool:
    """Check if the API is healthy."""
    try:
        response = requests.get(f"{API_URL}/health", timeout=5)
        data = response.json()
        return data["status"] == "healthy"
    except Exception:
        return False

def transcribe_audio(audio_path: str) -> str:
    """Transcribe an audio file with health check."""
    
    # Check health first
    if not check_health():
        raise Exception("API is not healthy")
    
    # Read and encode audio file
    with open(audio_path, "rb") as f:
        audio_base64 = base64.b64encode(f.read()).decode("utf-8")
    
    # Make API request
    response = requests.post(
        f"{API_URL}/transcribe",
        json={"audio_base64": audio_base64},
        headers={"Authorization": API_TOKEN},
        timeout=60
    )
    
    if response.status_code != 200:
        raise Exception(f"API Error: {response.json()['detail']}")
    
    return response.json()["transcript"]

# Usage
if __name__ == "__main__":
    try:
        transcript = transcribe_audio("audio.mp3")
        print(f"Transcript: {transcript}")
    except Exception as e:
        print(f"Error: {e}")
```

### JavaScript/Node.js

#### Basic Transcription

```javascript
const axios = require('axios');
const fs = require('fs');
require('dotenv').config();

const API_URL = 'http://localhost:8000';
const API_TOKEN = process.env.API_AUTH_TOKEN;

async function transcribeAudio(audioPath) {
  try {
    // Read and encode audio file
    const audioBuffer = fs.readFileSync(audioPath);
    const audioBase64 = audioBuffer.toString('base64');

    // Make API request
    const response = await axios.post(
      `${API_URL}/transcribe`,
      { audio_base64: audioBase64 },
      {
        headers: {
          'Authorization': API_TOKEN,
          'Content-Type': 'application/json'
        },
        timeout: 60000
      }
    );

    return response.data.transcript;
  } catch (error) {
    if (error.response) {
      throw new Error(`API Error: ${error.response.data.detail}`);
    }
    throw error;
  }
}

// Usage
(async () => {
  try {
    const transcript = await transcribeAudio('audio.mp3');
    console.log(`Transcript: ${transcript}`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
  }
})();
```

#### With Health Check

```javascript
const axios = require('axios');
const fs = require('fs');
require('dotenv').config();

const API_URL = 'http://localhost:8000';
const API_TOKEN = process.env.API_AUTH_TOKEN;

async function checkHealth() {
  try {
    const response = await axios.get(`${API_URL}/health`, { timeout: 5000 });
    return response.data.status === 'healthy';
  } catch {
    return false;
  }
}

async function transcribeAudio(audioPath) {
  // Check health first
  if (!(await checkHealth())) {
    throw new Error('API is not healthy');
  }

  // Read and encode audio file
  const audioBuffer = fs.readFileSync(audioPath);
  const audioBase64 = audioBuffer.toString('base64');

  // Make API request
  const response = await axios.post(
    `${API_URL}/transcribe`,
    { audio_base64: audioBase64 },
    {
      headers: {
        'Authorization': API_TOKEN,
        'Content-Type': 'application/json'
      },
      timeout: 60000
    }
  );

  return response.data.transcript;
}

// Usage
(async () => {
  try {
    const transcript = await transcribeAudio('audio.mp3');
    console.log(`Transcript: ${transcript}`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
  }
})();
```

### cURL

#### Health Check
```bash
curl -X GET http://localhost:8000/health
```

#### Transcribe Audio
```bash
# Using a local file
TOKEN="your_auth_token_here"
AUDIO_BASE64=$(base64 -i audio.mp3 -o - | tr -d '\n')

curl -X POST http://localhost:8000/transcribe \
  -H "Content-Type: application/json" \
  -H "Authorization: $TOKEN" \
  -d "{\"audio_base64\":\"$AUDIO_BASE64\"}"
```

#### With jq (using file)
```bash
TOKEN="your_auth_token_here"

curl -X POST http://localhost:8000/transcribe \
  -H "Content-Type: application/json" \
  -H "Authorization: $TOKEN" \
  -d @<(jq -n --rawfile audio <(base64 -i audio.mp3 -o -) '{audio_base64: $audio}')
```

---

## FAQ

### Q: How do I generate a new authorization token?
A: Use OpenSSL to generate a secure random token:
```bash
openssl rand -hex 32
```
Then add it to your `.env` file as `API_AUTH_TOKEN=<generated_token>`.

### Q: What is the maximum audio file size?
A: The maximum base64-encoded size is approximately 100 MB. This translates to roughly 75 MB of uncompressed audio. For larger files, consider compressing or splitting the audio.

### Q: How long does transcription take?
A: Processing time depends on:
- Audio length
- Audio quality/bitrate
- Whisper model size (large-v3)
- LLM provider performance
- System resources

Typical times range from 2-30 seconds for 1-5 minute audio clips.

### Q: Which LLM provider should I use?
A: 
- **Ollama**: Lightweight, easier to set up, good for local development
- **LM Studio**: More features, better UI, suitable for production

Choose based on your resource constraints and feature requirements.

### Q: Can I use this API without authentication?
A: No, the `/transcribe` endpoint requires authentication. The `/health` endpoint is public.

### Q: How do I troubleshoot connection issues?
A:
1. Check if the API is running: `curl http://localhost:8000/health`
2. Check LLM provider health in the response
3. Verify `.env` configuration matches your setup
4. Check firewall rules and port availability
5. Review container logs: `docker-compose logs -f`

### Q: What should I do if I get a 500 error?
A: 
1. Check the error message for details
2. Verify LLM provider is running and accessible
3. Check API logs for more information
4. Ensure the API has proper network access to the LLM server
5. Consider increasing timeout values if the LLM is slow

### Q: Can I run multiple instances of the API?
A: Yes, with proper load balancing. Each instance should connect to the same LLM server to avoid conflicts. Use a reverse proxy (nginx, Caddy) for load distribution.

### Q: How do I monitor the API?
A: 
- Use the `/health` endpoint for regular health checks
- Monitor container logs with `docker-compose logs`
- Set up alerts based on health status changes
- Track request latency and error rates

---

## Support

For issues, feature requests, or contributions, visit the project repository.

**Last Updated:** January 2026  
**API Version:** 1.0.0

