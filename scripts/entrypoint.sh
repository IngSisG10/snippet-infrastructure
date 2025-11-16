#!/bin/sh
set -e

# --- Lógica para crear un certificado DUMMY si no existe ---
if [ ! -f "/etc/letsencrypt/live/grupo10ingsis.duckdns.org/fullchain.pem" ]; then
  echo ">>> Generando certificado SSL dummy para que Nginx pueda arrancar..."
  mkdir -p /etc/letsencrypt/live/grupo10ingsis.duckdns.org
  openssl req -x509 -nodes -newkey rsa:4096 -days 1 \
    -keyout "/etc/letsencrypt/live/grupo10ingsis.duckdns.org/privkey.pem" \
    -out "/etc/letsencrypt/live/grupo10ingsis.duckdns.org/fullchain.pem" \
    -subj "/CN=localhost"
  echo ">>> Certificado dummy generado."
fi

# Ejecuta el comando original del contenedor de Nginx
exec "$@"