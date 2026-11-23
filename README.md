# Kryfo (Dreadful Hardened Fork)

> [!NOTE]
> **Hardened Fork Notice**
>
> This repository is a private, hardened downstream fork of [Kryfo](https://github.com/GnosiWorks/Kryfo), engineered for enhanced coercion resistance, strict plausible absence, self-hosted push infrastructure, and privacy.
>
> Packaged under application ID `work.dreadful.kryfo` with a custom slate cyan seal (`#1E6B8A`) so it installs cleanly side-by-side with official upstream releases without conflict.

## Hardened Features & Enhancements

Compared to upstream Kryfo, this build introduces specific hardening measures, privacy improvements, and infrastructure independence:

- **Independent Application ID (`work.dreadful.kryfo`)**:
  Installs and operates side-by-side with the official Kryfo app without package or signature conflicts.
- **Distinct Visual Identity (Slate Cyan Seal `#1E6B8A`)**:
  The launcher icon seal background is tinted dark slate cyan instead of upstream orange, avoiding visual confusion on the home screen.
- **Coercion Resistance & Isolated Archive (Strict Plausible Absence & State Uniformity)**:
  - **Mandatory App Lock PIN**: Setting a main App PIN (4+ digits) is required during initial onboarding and account restore, and cannot be skipped. Once set, the app lock cannot be disabled in Settings (only changed), ensuring private keys and databases are never exposed in plaintext.
  - **Isolated Archive with Inverted Default**:
    - Avoids conspicuous wording like "hidden chats" or "secret vault" across all languages, presenting the feature as a standard, legitimate isolated archive.
    - The prominent default action on onboarding and restore is simply **Continue**. The option to configure an isolated archive is presented as an unobtrusive secondary choice (**Set up isolated archive**).
    - **Automatic Random Sealing (State Uniformity)**: When proceeding with the default "Continue", Kryfo automatically generates a cryptographically secure random 16-digit PIN (`Random.secure()`) and transparently initializes the vault before sealing it. As a result, **100% of Kryfo installations possess an initialized SQLCipher database (`k3.db`), valid slot 3 credentials, and public sealing key metadata**, preventing forensic analysts from differentiating between users who skipped the setup and users who actively use an isolated archive.
    - **Strict Plausible Absence**: No archive setup or mention is exposed in everyday Settings from the outside. An adversary inspecting the unlocked device cannot tell whether an isolated archive is in use or not. Isolated conversations can only be unlocked and managed from within the archive by typing the dedicated PIN on the lock keypad.
- **Clean Slate (No Upstream Developer Telemetry or Contacts)**:
  - Removed the hardcoded developer contact card ("Marios") from the chat list.
  - Removed devchat, story submission, and upstream support reporting (`gnosiworks@proton.me`) from Settings.
  - Removed upstream social media links (`FollowSection`).
  - Repointed all source code and license references to [github.com/CyberPingU/Kryfo](https://github.com/CyberPingU/Kryfo).
- **Dual Flavors & Self-Hosted Push Gateway**:
  - **FOSS (`-foss.apk`)**: 100% tracker-free, zero Google/FCM dependencies (Tor always-on or UnifiedPush via ntfy).
  - **Play (`-play.apk`)**: Native Google Play Services Push (FCM wake-up ping) routed through private self-hosted push gateway at `r.dreadful.work` (ensuring URLs remain under the 512-byte Tor/relay seal limit). Works reliably without battery drain or companion apps on Sandboxed Google Play (GrapheneOS) and standard Android.
- **Zero-Drop Push Delivery & Battery Hardening**:
  - Disables upstream's artificial 1-month-in-5 contact rest rotation (`restsNow`), ensuring non-vault contacts remain 100% registered to instant push notifications at all times (vault chats remain strictly excluded).
  - Reduces fallback background `HaloPeriodicJobService` timeout from 170s to 35s to prevent Android 14/15 JobScheduler ANRs and wakelock timeouts (`timeout-reg`), allowing battery profile to run on standard "Optimized" without wakelock leaks.
- **Automated CI & Reproducible Container Toolchain**:
  - Automatically checks and syncs upstream tags via GitHub Actions.
  - Dynamically applies all modular patches (`patches/*.patch`) on clean upstream checkouts.
  - Built using the reproducible container toolchain and permanently signed with a dedicated release keystore for seamless updates via [Obtainium](https://github.com/ImranR98/Obtainium).

---

## Support the official Kryfo project

Kryfo was created and is actively maintained by Marios at **GnosiWorks**. If you appreciate Kryfo, please consider supporting the official upstream project and development:

- **Official website**: [kryfo.app](https://kryfo.app)
- **Upstream repository**: [github.com/GnosiWorks/Kryfo](https://github.com/GnosiWorks/Kryfo)
- **Security audit fund & donations**: [Open Collective](https://opencollective.com/kryfo)
- **Grant support**: [OpenSats Project Grant](https://opensats.org)

---

## About Kryfo

Kryfo is a private messenger for Android, with beta builds for Windows and Linux.
There is no phone number, no email and no account, and messages travel end-to-end encrypted over Tor.

### Core Principles

- **No phone number, email or account.** Your identity is three words, generated on your phone. Nobody can look you up unless you pick a public @name, which is disabled by default.
- **Tor by default.** Messages go phone-to-phone over Tor when both phones are online, and otherwise wait sealed on Nostr relays reached through Tor. When Tor is blocked, automatic mode tries bridges (Snowflake, WebTunnel, obfs4) and keeps the first one that works. Fast mode connects directly to designated relays (THREAT_MODEL.md outlines the trade-offs).
- **Signal protocol, post-quantum.** Chats use libsignal. Between modern clients, chats start with PQXDH and run SPQR (Signal's post-quantum ratchet) alongside the double ratchet.
- **Decoy PIN and hidden chats.** A decoy PIN opens an empty Kryfo, as if freshly installed. Hidden chats open only with their dedicated vault PIN. A wipe PIN permanently destroys all local data.
- **Zero-knowledge relays.** No accounts, no IP logs, no contact lists, no member lists. When the recipient is offline, encrypted messages wait sealed on relays for up to 14 days. Relays cannot decrypt messages or determine sender identities.
- **No telemetry, no contact upload, no ads.**

Also included: encrypted groups, files up to 50 MB, voice notes with on-device transcripts, disappearing messages, desktop companion pairing, offline translation, encrypted backups, and customizable disguised home screen icons.

---

## Install

Download release APKs from [GitHub Releases](https://github.com/CyberPingU/Kryfo/releases):

- **`Kryfo-Dreadful-v*-play.apk`**: Recommended for devices with Google Play Services or GrapheneOS Sandboxed Google Play. Uses our self-hosted push gateway (`r.dreadful.work`) for instant push wake-ups without running persistent background sockets.
- **`Kryfo-Dreadful-v*-foss.apk`**: 100% FOSS, zero Google dependencies. Ideal for fully de-Googled devices using Tor persistent connection or UnifiedPush (ntfy).

### Automatic Updates with Obtainium
To receive automatic update notifications and one-click installs:
1. Open [Obtainium](https://github.com/ImranR98/Obtainium).
2. Tap **Add App** and paste `https://github.com/CyberPingU/Kryfo`.
3. In **Filter APKs by regular expression**, enter your desired flavor (e.g., `-play\.apk$` or `-foss\.apk$`).
4. Save and install.

---

## Build from Source

The build uses a reproducible container toolchain. For local builds:

```bash
cd engine && ./build.sh
cd .. && mobile/native/kryfo_signal/build-android.sh
cd mobile && flutter pub get --offline
flutter build apk --release --split-per-abi --flavor play # or --flavor foss
```

Or run the automated packaging script:

```bash
./packaging/build-dreadful-apk.sh play
```

---

## Documentation

- [THREAT_MODEL.md](THREAT_MODEL.md): Threat model and security guarantees
- [PRIVACY.md](PRIVACY.md): Data handling and server privacy specifications
- [FORWARD_SECRECY.md](docs/FORWARD_SECRECY.md): Forward secrecy and post-quantum ratcheting
- [SERVERS.md](docs/SERVERS.md): Relay and server architecture details
- [BUILDING.md](BUILDING.md): Build instructions and toolchain details
- [CHANGELOG.md](CHANGELOG.md): Upstream release history

---

## Security

If you discover a security vulnerability in this fork, please report it privately via GitHub:
- [Submit a Private Security Advisory](https://github.com/CyberPingU/Kryfo/security/advisories/new)

---

## Licence

GPL-3.0-or-later, see [LICENSE](LICENSE). The sticker art is CC BY-SA 4.0, see `mobile/tool/stickers/fokia/LICENSE.md` and `mobile/tool/stickers/fokiaremix/LICENSE.md`.
