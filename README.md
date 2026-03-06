# NvidiaBar

NvidiaBar is a macOS menu bar app for monitoring NVIDIA GPU usage across remote SSH servers.

## Open-source release model

- Release builds are produced by GitHub Actions and uploaded to GitHub Releases as a downloadable `.zip`.
- The repository does not ship with any personal server addresses, SSH keys, or passwords.
- Server configuration is local-only and stored in `UserDefaults` on each machine.
- A public template is provided at [`config/server-config.template.json`](config/server-config.template.json).

## Local development

Build a local `.app` bundle:

```bash
zsh scripts/build_app.sh
```

Install into `/Applications`:

```bash
zsh scripts/install_app.sh
```

Create a release archive:

```bash
zsh scripts/package_release.sh 0.1.0
```

## GitHub release flow

1. Push a tag like `v0.1.0`.
2. GitHub Actions runs `.github/workflows/release.yml`.
3. The workflow builds `NvidiaBar.app`, zips it, and uploads `NvidiaBar-0.1.0.zip` to the matching GitHub Release.

## Public publishing hygiene

- Use a neutral Git author identity before creating the public repository history.
- Avoid pushing a branch whose commit metadata still contains your personal name or email.
- The app bundle identifier for public builds is `io.github.nvidiabar.app`.

## Personal environment hygiene

- Keep your real SSH aliases in local app settings only.
- Do not commit private config exports.
- If you need a private reference file, copy `config/server-config.template.json` to a path outside this repository and fill in your own values there.
- The current app uses the system `ssh` command and never stores passwords itself.
