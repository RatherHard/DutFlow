# dutflow

Discover a Windows PC's changing LAN address, then connect from Arch Linux
using SSH or Sunshine/Moonlight. The public rendezvous service exchanges
addresses only; it does not relay SSH or streaming traffic.

中文使用说明见 `使用说明.md`；开源发布步骤见 `开源发布说明.md`。

## Private configuration

- Arch: copy `.env.example` to `~/.config/dutflow/.env`, fill in your own values,
  and set mode `600`. Existing `~/.config/dutflow/config` remains supported.
  `DUTFLOW_CONFIG` can select another trusted Bash-compatible config file.
- Windows: copy `windows/config.example.json` to `windows/config.local.json`,
  fill in your values, then run `windows/install.ps1` as Administrator.
  Runtime config is stored outside the repository in `%ProgramData%\Dutflow\config.json`.
- Server: `server/install.sh` generates a private token and environment file in
  `/etc/dutflow`. The token is not printed. Provision valid HTTPS using your own
  domain/certificate; `server/nginx-dutflow.conf` is a template, not a deployed config.
- Sunshine credentials stay in the Windows user's encrypted credential export;
  do not put passwords or private keys in committed examples.

Real `.env` files, private config, credentials, keys, logs and local deployment
notes are ignored. **Ignore rules do not remove data from existing Git history.**

## Commands (Arch desktop terminal)

```bash
dutflow ip
dutflow ssh
dutflow check
dutflow stream Desktop
```

Current scope: one Windows host, one announced address. Network reachability,
SSH host-key verification and access control must be configured separately.
This project has no strict LAN-address/route enforcement or offline cache yet.
A successful address lookup alone is not proof of a direct LAN connection.

## Checks

```bash
bash tests/client.sh
python -m unittest discover -s tests -p 'test_*.py'
```

## License

MIT — see `LICENSE`. Third-party applications are installed separately and are
not relicensed by this repository.
