# WireGuard

This directory runs `wg-easy` on Unraid for remote access into the homelab.

Keep this VPN outside Kubernetes so it remains available when the cluster,
Gateway API, Cilium, or Dex are broken.

## Network Model

There are three different networks to keep separate:

| Purpose | Example | Notes |
| --- | --- | --- |
| Unraid management LAN | `10.20.30.50` | Where the wg-easy UI is exposed. |
| WireGuard client tunnel subnet | `10.29.0.0/24` | Address range assigned to VPN clients. |
| Docker bridge subnet | `172.31.42.0/24` | Internal container network only. Do not route clients here. |

The `172.31.42.0/24` subnet in `docker-compose.yml` is only for Docker's
private bridge network. It is not the VPN client subnet and should not match a
real LAN, VLAN, storage, or future routed network.

The WireGuard client tunnel subnet is configured during the wg-easy v15
first-run setup through:

```text
WG_TUNNEL_IPV4_CIDR=10.29.0.0/24
```

That example creates clients in the `10.29.0.0/24` VPN subnet.

Pick a VPN client subnet that does not overlap any home, hotel, mobile hotspot,
LAN, storage, Kubernetes, or Docker network. A good example is:

```text
10.29.0.0/24
```

Avoid using:

```text
10.20.30.0/24  # management LAN
10.20.90.0/24  # storage VLAN
10.244.0.0/16  # Kubernetes pods
10.96.0.0/12   # Kubernetes services
172.31.42.0/24 # Docker bridge for this compose stack
```

## Setup

Copy the example environment file:

```bash
cp .env.example .env
```

Adjust the values:

```text
WG_HOST=vpn.mbhome.biz
WIREGUARD_PORT=51028
DDNS_DOMAINS=vpn.mbhome.biz
WG_TUNNEL_IPV4_CIDR=10.29.0.0/24
WG_DEFAULT_DNS=10.20.30.11,10.20.30.12,10.20.30.1
WG_EASY_UI_BIND_IP=10.20.30.50
WG_EASY_UI_PORT=51128
WG_EASY_INIT_ENABLED=true
WG_EASY_INIT_USERNAME=admin
WG_EASY_INIT_PASSWORD=<long-local-admin-password>
```

`WIREGUARD_PORT` is used for both the published UDP listener and the public
endpoint port that should be written into new peer configs:

```text
Endpoint = vpn.mbhome.biz:51028
```

For wg-easy v15, the setup values are persisted in a SQLite database under
`./wireguard/` after the first setup. `WG_EASY_INIT_ENABLED=false` does not skip
initialization; it only disables unattended initialization and makes wg-easy use
the web setup wizard instead. To make `.env` drive the first setup, set
`WG_EASY_INIT_ENABLED=true` before the first container start.

After `./wireguard/` contains an initialized wg-easy v15 database, changing
`.env` does not rewrite wg-easy settings or existing peers. If a client is still
generated as `vpn.mbhome.biz:51820`, update the host/port in the wg-easy admin
UI, then recreate or edit that peer. To re-run unattended setup from scratch,
stop the stack and move `./wireguard/` out of the way first.

Start the service:

```bash
docker compose up -d
```

Open the UI from the LAN:

```text
http://10.20.30.50:51128
```

Do not expose the UI port to the internet. Only forward the WireGuard UDP port
on the router:

```text
UDP/51028 -> 10.20.30.50:51028
```

If you change `WIREGUARD_PORT` in `.env`, update the router port forwarding to
match that value:

```text
UDP/WIREGUARD_PORT -> 10.20.30.50:WIREGUARD_PORT
```

## Dynamic DNS

The compose stack includes a Cloudflare DDNS updater for the public VPN record.
It updates the `A` record listed in `DDNS_DOMAINS`, normally the same hostname
used by `WG_HOST`.

Recommended public DNS record:

```text
vpn.mbhome.biz  A  <current home public IP>  DNS only
```

Do not enable Cloudflare proxying for the VPN record. WireGuard uses UDP, and
Cloudflare's normal DNS proxy does not proxy arbitrary UDP WireGuard traffic.

Create a Cloudflare API token scoped to the DNS zone with:

```text
Zone:Read
Zone:DNS:Edit
```

Store the token locally on Unraid:

```bash
mkdir -p secrets
printf '%s' '<cloudflare-api-token>' > secrets/cloudflare_api_token.txt
chown 1000:1000 secrets/cloudflare_api_token.txt
chmod 0400 secrets/cloudflare_api_token.txt
```

The file must contain only the raw Cloudflare token value. Do not include
quotes, `Bearer`, `CLOUDFLARE_API_TOKEN=`, or any surrounding whitespace.

The `cloudflare-ddns` container runs as `DDNS_UID:DDNS_GID`, which defaults to
`1000:1000`. If you change those values in `.env`, also change the file owner to
the same UID/GID. If ownership is awkward on Unraid, `chmod 0444
secrets/cloudflare_api_token.txt` also works, but is less private.

Validate the token before starting the container:

```bash
TOKEN="$(tr -d '\r\n' < secrets/cloudflare_api_token.txt)"
curl -fsS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  https://api.cloudflare.com/client/v4/user/tokens/verify
unset TOKEN
```

If `cloudflare-ddns` logs `Invalid request headers (6003)`, recreate the secret
file from the raw token. That error normally means Cloudflare rejected the
Authorization header before it could check the zone.

Start or refresh the stack:

```bash
docker compose up -d
```

Check DDNS logs:

```bash
docker compose logs -f cloudflare-ddns
```

Validate public DNS:

```bash
dig +short vpn.mbhome.biz @1.1.1.1
```

If your router WAN address is in `100.64.0.0/10`, your ISP is probably using
CGNAT. In that case, DDNS can update the record, but inbound WireGuard traffic
still will not reach your router without a relay or a different ISP/public IP
arrangement.

## Client Routes

For remote admin access to the homelab, configure new clients in the wg-easy UI
as split tunnel with the following allowed IPs:

```text
10.20.30.0/24
```

This routes the management LAN through the VPN, but keeps the client's normal
internet traffic local.

Keep the storage VLAN off normal VPN clients. The remote internet connection is
not going to benefit from the 10Gbps storage path, and it is cleaner to reach a
lab node over the management LAN first when storage-network testing is needed.
For a temporary admin/debug peer that really needs direct storage VLAN access,
use:

```text
10.20.30.0/24,10.20.90.0/24
```

If you want full-tunnel VPN later, use:

```text
0.0.0.0/0
```

## DNS

Set VPN clients to use the AD DNS servers so internal names resolve:

```text
WG_DEFAULT_DNS=10.20.30.11,10.20.30.12
```

If the client may connect while the DCs are unavailable, add the router as a
third fallback DNS server:

```text
WG_DEFAULT_DNS=10.20.30.11,10.20.30.12,10.20.30.1
```

## Validation

From a VPN client:

```bash
ping 10.20.30.50
nslookup k8s-api.mbhome.biz 10.20.30.11
curl -k https://k8s-api.mbhome.biz:6443/readyz
```

`/readyz` should return `Unauthorized` from Kubernetes when connectivity is
working but no Kubernetes credentials are supplied.

## Notes

- `wg-easy` stores generated keys and peer config under `./wireguard/`.
- `./wireguard/`, `./secrets/`, and `.env` are intentionally ignored by Git.
- Changes to `WG_DEFAULT_ADDRESS`, `WG_DEFAULT_DNS`, or `WG_ALLOWED_IPS` are
  safest before creating peers. Existing generated peer configs may need to be
  recreated or updated manually after those values change.
- If you later proxy the UI through HTTPS, set `WG_EASY_INSECURE=false` and
  route the UI only through the reverse proxy.
