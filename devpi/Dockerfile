FROM python:3.11-slim

# Install required system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user to run devpi
RUN useradd -m -U devpi

# Install devpi-server and devpi-web
RUN pip install devpi-server devpi-web

# Create necessary directories and set ownership
RUN mkdir -p /data/devpi && \
    chown -R devpi:devpi /data/devpi

# Switch to non-root user
USER devpi

# Initialize devpi-server
RUN devpi-init --serverdir /data/devpi

# Expose the default devpi port
EXPOSE 3141

# Set the server directory
ENV DEVPI_SERVERDIR=/data/devpi

# Start devpi-server
CMD ["devpi-server", "--host", "0.0.0.0", "--port", "3141", "--serverdir", "/data/devpi"] 