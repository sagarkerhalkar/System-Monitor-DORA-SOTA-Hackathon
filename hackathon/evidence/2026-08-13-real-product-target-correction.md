# Real Product Target Correction — 2026-08-13

## Decision

The mentor-facing and hackathon target application is the user's real System Monitor product served from the local Windows server and exposed through:

`https://monitor.sagarkerhalkar.com/`

The separate `hackathon/ui` DORA/SOTA page is retained only as prior DevOps evidence and must not be presented as the product UI.

## Real product runtime

Known local source/runtime layout from prior working System Monitor builds:

- `D:\SagarSystemHealthMonitor\server.py`
- `D:\SagarSystemHealthMonitor\public\index.html`
- `D:\SagarSystemHealthMonitor\public\app.js`
- `D:\SagarSystemHealthMonitor\public\styles.css`
- application data under the System Monitor data/database path
- application port: `2278`

The real product includes the existing System Monitor navigation and operational pages such as Dashboard/Command Center, Machine Fleet, Machine 360, Network + VPN, Hardware/Software inventory, USB/peripherals, change history, Day History, Client Messages, notifications/deployment/settings and related admin functions.

## Correct hackathon architecture

All future hackathon work must be based on the real product code and UI, not a replacement demo frontend.

1. Preserve the currently working local production instance and its data.
2. Create an isolated copy/build target from the exact current working source before any hackathon change.
3. Add hackathon functionality to the real product UI and/or backend using clearly separated modules/routes.
4. Keep CI/CD, DORA, AI Ops, observability, security, SBOM/signing and deployment evidence around the real product.
5. Where Kubernetes/EKS is required for progressive-delivery proof, deploy the SAME real product code/image to the isolated hackathon environment rather than a different frontend.
6. Do not claim that replay/snapshot/demo telemetry is live. If live agents are unavailable for mentor demonstration, label any replay/snapshot dataset clearly.
7. Production `workingcode` must not be overwritten by experimental changes. Promotion to the local production server happens only after backup, validation and explicit verification.

## Mentor demo rule

The first screen shown to the mentor must be the real System Monitor product at `https://monitor.sagarkerhalkar.com/` (or its local server URL if the public domain is unavailable). DevOps/DORA/Argo/GitHub evidence is shown afterward as the engineering layer behind the product.

## Existing hackathon requirements to retain

The corrected target still keeps the hackathon engineering goals already defined in the repository, including:

- GitHub CI
- immutable build/version evidence
- vulnerability scanning
- SBOM
- signing/attestation
- GitOps / Argo CD evidence where applicable
- Argo Rollouts progressive delivery `10% -> 25% -> 50% -> 100%`
- automated analysis/abort/rollback
- Prometheus/Grafana/Alertmanager
- Loki/Tempo/OpenTelemetry
- DORA metrics: deployment frequency, lead time, change failure rate, MTTR
- secrets/runtime security and HTTPS
- deliberate bad release and recovery proof
- final mentor report, screenshots and demo script

## Important correction

Hackathon 3.82 remains valid evidence that the isolated AWS AI Ops canary mechanism works. It does NOT prove that the full original System Monitor product UI is deployed to EKS. Future work must close that gap using the real product source.

## Security

No password, token, private key, cookie, database content or other secret is recorded here.
