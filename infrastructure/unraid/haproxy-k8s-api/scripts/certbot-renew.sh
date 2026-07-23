#!/bin/sh
set -eu

: "${CERTBOT_EMAIL:?Set CERTBOT_EMAIL}"
: "${CERTBOT_CERT_NAME:=mbhome.biz}"
: "${CERTBOT_DOMAINS:=mbhome.biz,*.mbhome.biz}"
: "${CLOUDFLARE_PROPAGATION_SECONDS:=60}"
: "${RENEW_INTERVAL_SECONDS:=43200}"

credentials_file="/run/secrets/cloudflare.ini"

if [ ! -f "$credentials_file" ]; then
  echo "Missing Cloudflare credentials file: $credentials_file" >&2
  exit 1
fi

domain_args=""
old_ifs="$IFS"
IFS=","
for domain in $CERTBOT_DOMAINS; do
  domain_args="$domain_args -d $domain"
done
IFS="$old_ifs"

# shellcheck disable=SC2086
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials "$credentials_file" \
  --dns-cloudflare-propagation-seconds "$CLOUDFLARE_PROPAGATION_SECONDS" \
  --cert-name "$CERTBOT_CERT_NAME" \
  --keep-until-expiring \
  --agree-tos \
  --non-interactive \
  -m "$CERTBOT_EMAIL" \
  $domain_args

install-haproxy-pem

while true; do
  certbot renew \
    --dns-cloudflare \
    --dns-cloudflare-credentials "$credentials_file" \
    --dns-cloudflare-propagation-seconds "$CLOUDFLARE_PROPAGATION_SECONDS" \
    --deploy-hook install-haproxy-pem

  install-haproxy-pem
  sleep "$RENEW_INTERVAL_SECONDS"
done
