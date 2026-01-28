FROM ghcr.io/open-webui/open-webui:main

# Open WebUI listens on 8080 in the container image.
# Code Engine will route traffic to this port (we set image_port=8080 in Terraform).
EXPOSE 8080

# Keep the image generic.
# Configuration is injected via environment variables in Code Engine.