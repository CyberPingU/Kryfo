# Security

If you discover a security vulnerability, flaw, or way to break encryption, bypass the app lock / hidden chats vault, or make the app or servers misbehave, please report it privately.

## How to report

Reports should be submitted through GitHub:

- **GitHub:** [Private security advisory](https://github.com/CyberPingU/Kryfo/security/advisories/new). Only the repository maintainers can see it.

Please do not open a public issue for an unpatched security problem.

## What to include

- What an attacker can do, and what prerequisites are required (network position, compromised relay, physical possession)
- The version (Settings -> Informazioni) and flavor installed (`-play` or `-foss`)
- The target device, Android/OS version, and build
- Steps to reproduce, or a proof of concept
- Whether you plan to publish, and when

## Scope

- **The app:** Android client (`mobile/`), cryptographic handshakes, storage, App PIN and hidden chats vault, decoy PIN, backups, Tor transport, push registrations.
- **The engine & libsignal:** Rust engine shims (`engine/`, `mobile/native/kryfo_signal/`).
- **Push & Relay Services:** Private push gateway at `r.dreadful.work` and relay infrastructure.
