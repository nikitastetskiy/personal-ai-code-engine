FROM ollama/ollama:latest

# Pre-pull the model at build time so the runtime container starts "warm".
# Note: This increases image build time and image size.
# If you prefer a smaller image, remove this and let the model download at runtime.
ARG OLLAMA_MODEL=deepseek-r1:8b

SHELL ["/bin/sh", "-lc"]

RUN set -eu; \
    echo "Starting temporary Ollama server to pull model: ${OLLAMA_MODEL}"; \
    (ollama serve > /tmp/ollama.log 2>&1 &) ; \
    sleep 3; \
    ollama pull "${OLLAMA_MODEL}"; \
    echo "Model pulled successfully"; \
    pkill ollama || true; \
    sleep 1

# Code Engine needs the correct port configured (we set image_port=11434 in Terraform).
EXPOSE 11434

# Start Ollama server
ENTRYPOINT ["ollama", "serve"]