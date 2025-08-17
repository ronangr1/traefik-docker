#!/bin/bash

# shellcheck disable=SC2162
read -p "Enter your primary domain (e.g., domain.localhost): " TLD

# Validate input
if [ -z "$TLD" ]; then
    echo "Error: Domain cannot be empty."
    exit 1
fi

# Define paths
CONFIG_DIR="$HOME/.docker/traefik-docker"
CERTS_DIR="$CONFIG_DIR/certs"
CONFIG_FILE="$CONFIG_DIR/dynamic_conf.yml"
COMPOSE_FILE="$CONFIG_DIR/compose.yaml"

# Generate dynamic_conf.yml
echo "Generating Traefik dynamic configuration..."
cat > "$CONFIG_FILE" <<EOL
http:
    routers:
        traefik-dashboard:
            rule: "Host(\`traefik.$TLD\`)"
            service: api@internal
            entryPoints:
                - websecure
            tls:
                domains:
                    - main: "$TLD"
                      sans:
                          - "*.$TLD"

tls:
    certificates:
        - certFile: "/certs/cert.pem"
          keyFile: "/certs/key.pem"
EOL

echo "Generate compose.yaml..."
cat > "$COMPOSE_FILE" <<EOL
services:
  reverse-proxy:
    image: traefik:3.5
    container_name: traefik
    restart: always
    network_mode: "host"
    command:
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--providers.docker=true"
      - "--providers.file.filename=/etc/traefik/dynamic_conf.yml"
      - "--api.dashboard=true"
      - "--log.level=DEBUG"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./certs:/certs:ro"
      - "./dynamic_conf.yml:/etc/traefik/dynamic_conf.yml:ro"

  mailhog:
    image: tsle/mail-mailhog-arm64:latest
    container_name: mailhog
    restart: always
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mailhog.rule=Host(\`mailhog.$TLD\`)"
      - "traefik.http.routers.mailhog.entrypoints=websecure"
      - "traefik.http.routers.mailhog.tls=true"
      - "traefik.http.services.mailhog.loadbalancer.server.port=8025"
    networks:
      - proxy
      - default

  #  mailhog:
  #    image: mailhog:latest
  #    container_name: mailhog
  #    restart: always
  #    labels:
  #      - "traefik.enable=true"
  #      - "traefik.http.routers.mailhog.rule=Host(\`mailhog.$TLD\`)"
  #      - "traefik.http.routers.mailhog.entrypoints=websecure"
  #      - "traefik.http.routers.mailhog.tls=true"
  #      - "traefik.http.services.mailhog.loadbalancer.server.port=8025"
  #    networks:
  #      - proxy
  #      - default

  swagger-ui:
    image: swaggerapi/swagger-ui:latest
    container_name: swagger-ui
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.swagger.rule=Host(\`swagger.$TLD\`)"
      - "traefik.http.routers.swagger.entrypoints=websecure"
      - "traefik.http.routers.swagger.tls=true"
      - "traefik.http.services.swagger.loadbalancer.server.port=8080"
    networks:
      - proxy
      - default

  portainer:
    image: portainer/portainer
    container_name: portainer
    restart: always
    volumes:
      - "portainer_data:/data"
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    labels:
        - "traefik.enable=true"
        - "traefik.http.routers.portainer.rule=Host(\`portainer.$TLD\`)"
        - "traefik.http.routers.portainer.entrypoints=websecure"
        - "traefik.http.routers.portainer.tls=true"
        - "traefik.http.services.portainer.loadbalancer.server.port=9000"
    networks:
      - default

volumes:
  portainer_data:
    name: portainer_data
    driver: local

networks:
  proxy:
    name: proxy
  default:
EOL

# Create directories if they don't exist
mkdir -p "$CERTS_DIR"

# Generate SSL certificates
echo "Generating SSL certificates for $TLD and *.$TLD..."
if ! command -v mkcert &> /dev/null; then
    echo "Error: mkcert is not installed. Please install it first (brew install mkcert or apt install mkcert)."
    exit 1
fi

mkcert -key-file "$CERTS_DIR/key.pem" -cert-file "$CERTS_DIR/cert.pem" "$TLD" "*.$TLD"

# Install mkcert root CA (if not already installed)
if ! mkcert -install; then
    echo "Warning: Failed to install mkcert root CA."
    exit 1
fi

echo "🎉 Domain '$TLD' has been successfully configured!"
echo "You may need to restart your browser to load the new root CA and trust these certificates."
echo "Happy coding!"