#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
readonly APP=/opt/dutflow
readonly ETC=/etc/dutflow
readonly TOKEN_FILE=$ETC/token
install -d -m 0755 "$APP" /var/lib/dutflow
install -d -m 0700 "$ETC"
install -m 0755 dutflow-rendezvous.py "$APP/dutflow-rendezvous.py"
if ! id dutflow >/dev/null 2>&1; then useradd --system --home-dir /var/lib/dutflow --shell /usr/sbin/nologin dutflow; fi
if [[ ! -s "$TOKEN_FILE" ]]; then umask 077; openssl rand -hex 32 > "$TOKEN_FILE"; fi
TOKEN=$(tr -d '\n' < "$TOKEN_FILE")
printf 'DUTFLOW_TOKEN=%s\nDUTFLOW_HOST=127.0.0.1\nDUTFLOW_PORT=18787\nDUTFLOW_STATE=/var/lib/dutflow/peers.json\n' "$TOKEN" > "$ETC/dutflow.env"
chmod 0600 "$ETC/dutflow.env" "$TOKEN_FILE"
chown -R dutflow:dutflow /var/lib/dutflow
install -m 0644 dutflow-rendezvous.service /etc/systemd/system/dutflow-rendezvous.service
systemctl daemon-reload
systemctl enable --now dutflow-rendezvous.service
# Keep the backend private; terminate HTTPS at nginx. Never print the token.
printf '%s\n' 'Installed. Configure HTTPS reverse proxy, then transfer /etc/dutflow/token securely.'
