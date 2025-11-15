#!/bin/sh
# startup.sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Wait for the certificate to be generated
while ! [ -f /etc/letsencrypt/live/ingsisg10.duckdns.org/fullchain.pem ]; do
  echo "Waiting for certificate to be generated..."
  sleep 5
done

# Start Nginx
nginx -g "daemon off;"
