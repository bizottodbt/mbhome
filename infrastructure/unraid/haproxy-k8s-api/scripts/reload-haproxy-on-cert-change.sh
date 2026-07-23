#!/bin/sh
set -eu

: "${HAPROXY_CONTAINER:=haproxy}"
: "${WATCH_FILE:=/certs/mbhome.biz.pem}"
: "${WATCH_INTERVAL_SECONDS:=300}"

previous=""

while true; do
  if [ -f "$WATCH_FILE" ]; then
    current="$(sha256sum "$WATCH_FILE" | awk '{print $1}')"
    if [ -n "$previous" ] && [ "$current" != "$previous" ]; then
      echo "Certificate changed; restarting $HAPROXY_CONTAINER"
      docker restart "$HAPROXY_CONTAINER"
    fi
    previous="$current"
  fi

  sleep "$WATCH_INTERVAL_SECONDS"
done
