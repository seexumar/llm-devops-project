#Hardened Runtime Image
FROM ollama/ollama:latest

# Set environment variables for production execution
ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_MODELS=/home/llmuser/.ollama/models \
    OLLAMA_KEEP_ALIVE=24h

# Create non-root system user and set directory permissions
RUN groupadd -g 10001 llmgroup && \
    useradd -u 10001 -g llmgroup -s /bin/bash -m llmuser && \
    mkdir -p /home/llmuser/.ollama && \
    chown -R llmuser:llmgroup /home/llmuser

# Expose default API port
EXPOSE 11434

# Switch to non-root user
USER 10001

# Built-in container health check
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD ollama list || exit 1

ENTRYPOINT ["ollama", "serve"]