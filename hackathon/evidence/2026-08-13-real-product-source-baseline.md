# Hackathon 3.83 — Real Product Source Baseline

Date: 2026-08-13
Target product: `https://monitor.sagarkerhalkar.com/`
Production source root reported by owner: `D:\SagarSystemHealthMonitor`

## Purpose

This evidence records the exact source-only snapshot supplied from the currently working local System Monitor product before any hackathon modification. The running production instance was not stopped or changed.

## Uploaded source snapshot

Two ZIP archives were supplied with the same timestamp. Their ZIP container hashes differ because one archive contains a wrapper directory / different path separator representation, but normalized file entries match file-for-file by path, size and CRC.

Normalized source contents: 54 files.

Current core file SHA-256 values:

- `server.py`: `dc6b242c3edb1ffd065861df12eda03225430ef8b71bd3757cd54935437d8cff`
- `public/app.js`: `ae7c814530e263456e5f58ba932abefd7a5b55f47954b47a0ab85feb18a57ae3`
- `public/index.html`: `36a845e5728cd84b0fe476021903115e970a455278826427fcf07f4bba5ab434`
- `public/styles.css`: `c9fe42643520575e660232d6e8c53f45d6f3e96399fe0d93c1c070853895099d`

## Snapshot safety

PASS:
- No `monitor.db` database file was included.
- No runtime log directory was included.
- No private key/certificate file was included.
- Core product source and branding assets are present.

SECURITY FINDING:
- The supplied `server.py` contains a hard-coded fallback administrator password if the expected environment variable is absent.
- The secret value is intentionally NOT reproduced in this evidence and the raw source snapshot must not be published unchanged.
- Hackathon import must remove the fallback and require a runtime secret/environment value.

Additional hygiene:
- The snapshot contains many historical `.bak`, `.before_*` and `.tmp` UI files. These are production recovery artifacts and must not be imported into the public hackathon source tree.

## Real product UI map

The current `public/index.html` contains 13 matching navigation/page IDs:

1. Command Center (`dashboard`)
2. Machine Fleet (`fleet`)
3. Machine 360 (`machine360`)
4. Network + VPN (`network`)
5. Hardware Analytics (`hardware`)
6. Software Inventory (`software`)
7. USB + Peripherals (`usb`)
8. Human Change Log (`changes`)
9. Day History (`history`)
10. Client Messages (`messages`)
11. Notifications (`notifications`)
12. Deploy (`deploy`)
13. Settings (`settings`)

This is the mentor-facing product UI. The separate `hackathon/ui` DORA page is supporting delivery/operations evidence only and must not be presented as the product.

## Source validation

PASS:
- `server.py` Python syntax compilation succeeds.
- `public/app.js` passes Node.js `--check` syntax validation.
- Isolated smoke test launched the exact server source on loopback with a temporary environment-only administrator password.
- `GET /api/health` returned `ok: true`.
- `POST /api/auth/login` succeeded with the temporary test credential.
- Authenticated `GET /api/overview` returned the dashboard data contract.

The smoke-test database was temporary and separate from production data.

## Existing API surface observed

The source contains the real product APIs for health/auth, machines, machine detail, overview, hardware/software inventory, USB, history/day-history, changes, messages, notifications, settings/users, retention, ISP/network tests and exports.

## Corrected hackathon integration boundary

1. Keep the running local production application protected.
2. Create a sanitized isolated copy from this exact baseline.
3. Use the SAME real System Monitor UI/backend as the application image for hackathon deployment/progressive-delivery proof.
4. Do not publish raw production secrets, DB content, logs, backups or recovery files.
5. If live agents are unavailable during mentor review, any replay/snapshot telemetry must be visibly labelled `Recorded/Demo Data` and must never be represented as live.
6. CI/CD, AI Ops, DORA, observability, security and progressive delivery are integrated around/inside the real product instead of replacing its UI.

## Next action

Build the sanitized Hackathon 3.83 real-product source tree from the four active UI/server files plus required branding assets, remove the hard-coded admin fallback, add explicit runtime/demo provenance, and validate the isolated product before changing any EKS workload or the local production runtime.
