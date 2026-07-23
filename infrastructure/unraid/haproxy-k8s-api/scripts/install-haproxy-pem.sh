#!/bin/sh
set -eu

: "${CERTBOT_CERT_NAME:=mbhome.biz}"

live_dir="/etc/letsencrypt/live/$CERTBOT_CERT_NAME"
target="/certs/$CERTBOT_CERT_NAME.pem"
tmp="$target.tmp"

if [ ! -f "$live_dir/fullchain.pem" ] || [ ! -f "$live_dir/privkey.pem" ]; then
  echo "Certificate files are not ready under $live_dir" >&2
  exit 1
fi

cat "$live_dir/fullchain.pem" "$live_dir/privkey.pem" > "$tmp"
chmod 0644 "$tmp"
mv "$tmp" "$target"
echo "Wrote HAProxy PEM: $target"
