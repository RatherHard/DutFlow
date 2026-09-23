# Arch Linux installation

Run from the repository root. Requires Bash, curl, OpenSSH and Moonlight Qt.

```bash
sudo install -Dm755 archlinux/dutflow /usr/local/bin/dutflow
install -d -m700 "$HOME/.config/dutflow"
# First installation only: do not overwrite an existing working configuration.
install -m600 .env.example "$HOME/.config/dutflow/.env"
```

Edit `~/.config/dutflow/.env`: use your HTTPS rendezvous URL, server token,
Windows SSH username and dedicated SSH identity path. Only load trusted config
files: they are sourced by Bash. Keep private keys on the client.

Existing installations using `~/.config/dutflow/config` work unchanged unless a
new `.env` is present. An explicit `DUTFLOW_CONFIG` takes precedence.

Before first use, authorize the SSH public key on Windows, verify the Windows
host key, and configure Sunshine credentials. See `使用说明.md` for the full
Chinese guide.