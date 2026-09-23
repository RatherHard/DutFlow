#!/usr/bin/env bash
# Isolated CLI regression tests; no network or credentials used.
set -euo pipefail
client=$(realpath "${1:-archlinux/dutflow}")
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir "$tmp/bin"
export HOME="$tmp/home"
mkdir -p "$HOME/.config/dutflow"
unset DUTFLOW_URL DUTFLOW_TOKEN DUTFLOW_SSH_USER DUTFLOW_SSH_KEY
export DUTFLOW_CONFIG="$tmp/config" CAPTURE="$tmp/args"
printf 'DUTFLOW_URL=https://example.invalid\nDUTFLOW_TOKEN=test\nDUTFLOW_SSH_USER=test\n' > "$DUTFLOW_CONFIG"
cat > "$tmp/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CAPTURE.curl"
printf '{"ip":"192.168.1.100"}\n'
MOCK
cat > "$tmp/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CAPTURE"
MOCK
cp "$tmp/bin/ssh" "$tmp/bin/moonlight"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
bash "$client" pin 1234
tail -2 "$CAPTURE" | diff -u <(printf '%s\n' '-Pin' '1234') -
bash "$client" check
test "$(tail -1 "$CAPTURE")" = '-Check'
bash "$client" stream
diff -u <(printf '%s\n' stream 192.168.1.100 Desktop) "$CAPTURE"
if bash "$client" pin invalid; then echo 'Invalid PIN accepted' >&2; exit 1; fi
# Explicit config path wins, including over a default .env.
printf 'DUTFLOW_URL=https://dotenv.example.invalid\nDUTFLOW_TOKEN=dotenv-test\nDUTFLOW_SSH_USER=dotenv-user\n' > "$HOME/.config/dutflow/.env"
printf 'DUTFLOW_URL=https://legacy.example.invalid\nDUTFLOW_TOKEN=legacy-test\nDUTFLOW_SSH_USER=legacy-user\n' > "$HOME/.config/dutflow/config"
bash "$client" ssh hostname
grep -Fxq 'test@192.168.1.100' "$CAPTURE"
grep -Fxq 'https://example.invalid/v1/resolve' "$CAPTURE.curl"

# Missing explicit config must fail rather than fall back to another host.
if DUTFLOW_CONFIG="$tmp/missing" bash "$client" ip > "$tmp/out" 2> "$tmp/error"; then
 echo 'Missing explicit config accepted' >&2; exit 1
fi
grep -q 'Missing config' "$tmp/error"

# New default takes precedence over legacy config.
unset DUTFLOW_CONFIG
bash "$client" ssh hostname
grep -Fxq 'dotenv-user@192.168.1.100' "$CAPTURE"
grep -Fxq 'Authorization: Bearer dotenv-test' "$CAPTURE.curl"

# Legacy deployments still work when .env is absent.
mv "$HOME/.config/dutflow/.env" "$tmp/dotenv"
bash "$client" ssh hostname
grep -Fxq 'legacy-user@192.168.1.100' "$CAPTURE"

# Missing required values fail before any network request; no token in output.
printf 'DUTFLOW_URL=https://example.invalid\nDUTFLOW_TOKEN=example-test-token\n' > "$tmp/incomplete"
rm -f "$CAPTURE.curl"
if DUTFLOW_CONFIG="$tmp/incomplete" bash "$client" ip > "$tmp/out" 2> "$tmp/error"; then
 echo 'Incomplete config accepted' >&2; exit 1
fi
grep -q 'Config requires' "$tmp/error"
! grep -q 'example-test-token' "$tmp/error"
test ! -e "$CAPTURE.curl"
echo 'Client regression tests passed'
