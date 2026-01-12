# OpenWhisper Backend Docker Setup

This directory contains Dockerfile and docker-compose configuration for the OpenWhisper backend service.

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- (Optional) An `.env` file with your configuration variables

### Using Docker Compose

**Start all services:**
```bash
docker-compose up -d
```

**Stop all services:**
```bash
docker-compose down
```

**View logs:**
```bash
docker-compose logs -f backend
```

**Rebuild after code changes:**
```bash
docker-compose up -d --build
```

## Architecture

The docker-compose setup includes (by default):

1. **backend** - FastAPI application running on port 8000
2. **ollama** - Lightweight LLM provider running on port 11434

## Configuration

### Environment Variables

Create a `.env` file in the backend directory:

```dotenv
# Ollama Configuration (default)
OLLAMA_SERVER_URL=http://ollama
OLLAMA_SERVER_PORT=11434

# LM Studio Configuration (if using instead of Ollama)
LM_STUDIO_SERVER_URL=
LM_STUDIO_SERVER_PORT=

# LLM Provider selection
LLM_PROVIDER=ollama

# Model name
LLM_MODEL_NAME=llama2

# Authorization token (generate with: openssl rand -hex 32)
API_AUTH_TOKEN=your_secure_token_here
```

## Using Different LLM Providers

### Using External Ollama Service

If you're running Ollama locally on your machine (not in Docker):

1. Comment out the `ollama` service in `docker-compose.yml`:
   ```yaml
   # ollama:
   #   image: ollama/ollama:latest
   #   ...
   ```

2. Remove `ollama` from the backend's `depends_on`:
   ```yaml
   backend:
     # ...
     depends_on: []  # or remove this section entirely
   ```

3. Update your `.env` file to point to your local Ollama:
   ```dotenv
   OLLAMA_SERVER_URL=http://host.docker.internal
   OLLAMA_SERVER_PORT=11434
   LLM_PROVIDER=ollama
   ```
   
   **Note:** On Linux, use `http://localhost` instead of `http://host.docker.internal`

4. Make sure Ollama is running on your machine and the port is accessible

### Using External LM Studio Service

If you're running LM Studio locally on your machine (not in Docker):

1. Comment out the `ollama` service in `docker-compose.yml`:
   ```yaml
   # ollama:
   #   image: ollama/ollama:latest
   #   ...
   ```

2. Remove `ollama` from the backend's `depends_on`:
   ```yaml
   backend:
     # ...
     depends_on: []  # or remove this section entirely
   ```

3. Uncomment the `lm-studio` service in `docker-compose.yml` (if you want it managed by Docker):
   ```yaml
   lm-studio:
     image: lm-studio:latest
     container_name: lm-studio-server
     # ... rest of config
   ```
   Or leave it commented out if running locally.

4. Update your `.env` file for LM Studio:
   ```dotenv
   OLLAMA_SERVER_URL=
   OLLAMA_SERVER_PORT=
   LM_STUDIO_SERVER_URL=http://host.docker.internal
   LM_STUDIO_SERVER_PORT=1234
   LLM_PROVIDER=lm_studio
   ```
   
   **Note:** On Linux, use `http://localhost` instead of `http://host.docker.internal`

5. Make sure LM Studio is running on your machine and the port is accessible

### Using Remote Ollama or LM Studio Server

If you have Ollama or LM Studio running on a remote machine:

1. Comment out the `ollama` service in `docker-compose.yml`

2. Update your `.env` file with the remote server address:
   ```dotenv
   # For remote Ollama
   OLLAMA_SERVER_URL=http://192.168.1.100
   OLLAMA_SERVER_PORT=11434
   LLM_PROVIDER=ollama
   
   # OR for remote LM Studio
   OLLAMA_SERVER_URL=
   OLLAMA_SERVER_PORT=
   LM_STUDIO_SERVER_URL=http://192.168.1.100
   LM_STUDIO_SERVER_PORT=1234
   LLM_PROVIDER=lm_studio
   ```

3. Ensure the remote server is accessible from your Docker network (firewall rules, network connectivity, etc.)

## Building and Running

### Build Docker Image
```bash
docker build -t openwhisper-backend:latest .
```

### Run Container Standalone
```bash
docker run -p 8000:8000 \
  -e OLLAMA_SERVER_URL=http://host.docker.internal \
  -e OLLAMA_SERVER_PORT=11434 \
  -e LLM_PROVIDER=ollama \
  -e LLM_MODEL_NAME=llama2 \
  -e API_AUTH_TOKEN=your_token \
  openwhisper-backend:latest
```

## Testing

### Health Check
```bash
curl http://localhost:8000/health
```

### Transcribe Endpoint
```bash
curl -X POST http://localhost:8000/transcribe \
  -H "Content-Type: application/json" \
  -H "Authorization: your_api_auth_token" \
  -d '{"audio_base64":"your_base64_audio_here"}'
```

## Troubleshooting

### Backend cannot connect to LLM server
- **Using local Ollama/LM Studio:** Use `http://host.docker.internal` (Docker Desktop for Mac/Windows) or `http://localhost` (Linux) instead of `http://127.0.0.1`
- **Using Docker Ollama/LM Studio:** Ensure the service is running and the backend has the correct network configuration
- **Using remote server:** Ensure the server is reachable from your Docker environment

### Port conflicts
- If port 8000 is already in use, change the port mapping in docker-compose.yml:
  ```yaml
  ports:
    - "8001:8000"  # Map 8001 to internal 8000
  ```

### View service logs
```bash
# Backend logs
docker-compose logs -f backend

# Ollama logs
docker-compose logs -f ollama

# All logs
docker-compose logs -f
```

### Model not found in Ollama
```bash
# Pull a model into the running Ollama container
docker exec ollama-server ollama pull llama2

# Or with a specific tag
docker exec ollama-server ollama pull mistral:7b
```

## Production Considerations

1. **Use a proper `.env` file:** Generate a secure API_AUTH_TOKEN with `openssl rand -hex 32`
2. **Resource limits:** Add memory and CPU limits in docker-compose.yml
3. **Logging:** Configure proper logging drivers for production
4. **Network security:** Consider using a reverse proxy and SSL/TLS
5. **Model persistence:** Mount volumes for LLM models to persist between container restarts
6. **Health checks:** The backend includes automatic health checks via the `/health` endpoint

