# Host secrets (1Password + opnix)

Host secrets live in the shared `persops` 1Password vault. The read-only
`persops-opnix` service account materializes them with
[opnix](https://github.com/brizzbuzz/opnix); values never enter Git or the Nix
store. Each item's notes name the files it feeds.

| Item | Amalthea | Aglaea |
| --- | --- | --- |
| `restic amalthea` / `restic aglaea` | `/etc/secrets/restic/{password,repository,s3.env}` | `~/.config/restic/{password,repository,s3.env}` |
| `Restic - Archive Storage Box` | `/etc/secrets/restic-storage-box/password` | `~/.config/restic-storage-box/password` |
| `Hetzner Storage Box - <Host>` | `/etc/secrets/restic-storage-box/id_ed25519` | `~/.ssh/hetzner-storage-box-aglaea` |
| `Actual-Budget` | `/etc/secrets/actual-automation/{password,sync-id}` | |
| `ntfy-amalthea` | `/etc/secrets/ntfy-sh/environment` | |
| `kuma-job-tokens` (document) | `/etc/secrets/kuma-job-health/tokens.json` | |
| `amalthea login hash` | `/etc/secrets/login/cat.hash` (`hashedPasswordFile`) | |

Still manual, by design: the initrd SSH host key and sea16 LUKS key (needed
before the network is up), Actual's `enabled` kill-switch marker, pheme's
credentials (not a Nix host; `scripts/pheme-watch-install` injects them), and
cliproxyapi's self-generated API key.

## How it works

- **Amalthea** uses opnix's NixOS module (`modules/secrets/nixos.nix`).
  `opnix-secrets.service` fetches at boot and on deploy;
  `opnix-secrets-poll.timer` refetches every 6 hours. Single-value files are
  declared next to their consumer in `services.onepassword-secrets.secrets`.
- **Aglaea** fetches during Home Manager activation (`modules/secrets/home.nix`)
  with `persops.homeSecrets`. opnix's own Home Manager module is not used: it
  exits the whole activation when the token is missing.
- **Multi-value files** (env files, SSH keys that need a trailing newline) are
  `op inject`-style templates: `persops.secretTemplates` on NixOS and
  `persops.homeSecrets.templates` on Home Manager.
  `modules/secrets/render-secret-template.py` fills the `{{ op://persops/... }}`
  placeholders from opnix's raw files and writes the result atomically. On
  NixOS each template is a `persops-secret-<name>` unit that opnix re-runs when
  a value changes; `restartUnits` are then try-restarted.
- A failed fetch keeps the existing files, so hosts keep working offline.

## Bootstrap a host

The token lives in `Private/Service Account Auth Token: persops-opnix` (the
colon rules out an `op://` reference). From the 1Password tmux session on
aglaea:

```sh
token() { op item get "Service Account Auth Token: persops-opnix" --vault Private \
  --account my.1password.com --fields credential --reveal; }
token | ssh amalthea 'sudo install -m 0600 /dev/stdin /etc/opnix-token'
token | (umask 077 && mkdir -p ~/.config/opnix && cat >~/.config/opnix/token)
```

Then deploy. `opnix-secrets.service` hands the token to the
`onepassword-secrets` group itself.

## Change or rotate a value

1. Edit the field in the `persops` vault.
2. Amalthea picks it up within 6 hours, or now with
   `sudo systemctl start opnix-secrets-poll.service`. Aglaea picks it up on the
   next `make switch`.

To rotate the amalthea login, update both `Private/cat linux @ amalthea` and
`amalthea login hash` (`mkpasswd -m sha-512`). `persops-login-hash.service`
applies the new hash after the next fetch. Activation reads the same file and
locks the password while it is missing, so a fresh host has no password login
until opnix has fetched it once.

## Add a secret

- Single value: add a `services.onepassword-secrets.secrets.<camelCaseName>`
  entry (NixOS) or `persops.homeSecrets.files.<name>` (aglaea) with an explicit
  `path` and mode, and add a note to the 1Password item naming that path.
- Several values in one file: add a template. References must stay inside
  `op://persops/`; the service account cannot read other vaults.

Keep old 1Password fields until no deployed generation still references them.
