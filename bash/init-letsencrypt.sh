#!/usr/bin/env bash
set -e

########################################
# CONFIG
########################################

# Dominio(s) - usando tu DuckDNS
domains=(
  "grupo10ingsis.duckdns.org"
)

# Email para Let's Encrypt
email="franmanfredi@hotmail.com"

# Carpeta base de certbot en el host (ABSOLUTA)
data_path="/opt/app/data/certbot"

# Ruta ABSOLUTA al docker compose
compose_file="/opt/app/deploy-compose.yml"

# Tamaño de clave
rsa_key_size=4096

# 1 = staging (pruebas, sin quemar rate limit), 0 = prod
staging=1

########################################
# Detectar docker compose / docker-compose
########################################

if docker compose version &> /dev/null; then
  DC="docker compose"
elif command -v docker-compose &> /dev/null; then
  DC="docker-compose"
else
  echo "Error: no encontré ni 'docker compose' ni 'docker-compose' en el PATH." >&2
  exit 1
fi

# Verificar que el archivo de compose exista
if [ ! -f "$compose_file" ]; then
  echo "Error: no se encontró el archivo de compose en: $compose_file" >&2
  exit 1
fi

########################################
# Confirmar si ya existe data
########################################

if [ -d "$data_path" ]; then
  echo "Ya existe data en $data_path para los dominios: ${domains[*]}"
  read -p "¿Sobrescribir certificados existentes? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    echo "Abortando."
    exit 0
  fi
fi

########################################
# TLS params si faltan
########################################

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || \
   [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Descargando parámetros TLS recomendados..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
    > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem \
    > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

########################################
# Certificado DUMMY
########################################

main_domain="${domains[0]}"
echo "### Creando certificado DUMMY para $main_domain ..."

mkdir -p "$data_path/conf/live/$main_domain"

$DC -f "$compose_file" run --rm \
  --entrypoint openssl \
  certbot \
  req -x509 -nodes -newkey "rsa:${rsa_key_size}" -days 1 \
    -keyout "/etc/letsencrypt/live/$main_domain/privkey.pem" \
    -out "/etc/letsencrypt/live/$main_domain/fullchain.pem" \
    -subj "/CN=localhost"
echo

########################################
# Levantar nginx
########################################

echo "### Levantando nginx ..."
$DC -f "$compose_file" up --force-recreate -d nginx
echo

########################################
# Borrar DUMMY
########################################

echo "### Borrando certificado DUMMY para $main_domain ..."
$DC -f "$compose_file" run --rm \
  --entrypoint rm \
  certbot \
  -Rf \
  "/etc/letsencrypt/live/$main_domain" \
  "/etc/letsencrypt/archive/$main_domain" \
  "/etc/letsencrypt/renewal/$main_domain.conf" || true
echo

########################################
# Pedir cert real a Let's Encrypt
########################################

echo "### Solicitando certificado real para: ${domains[*]} ..."

domain_args=()
for d in "${domains[@]}"; do
  domain_args+=("-d" "$d")
done

if [ -z "$email" ]; then
  email_arg="--register-unsafely-without-email"
else
  email_arg="--email $email"
fi

staging_arg=""
if [ "$staging" != "0" ]; then
  staging_arg="--staging"
fi

$DC -f "$compose_file" run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  $staging_arg \
  $email_arg \
  "${domain_args[@]}" \
  --rsa-key-size "$rsa_key_size" \
  --agree-tos \
  --force-renewal
echo

########################################
# Recargar nginx
########################################

echo "### Recargando nginx con los nuevos certificados ..."
$DC -f "$compose_file" exec nginx nginx -s reload || true

echo "### Listo."