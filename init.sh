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