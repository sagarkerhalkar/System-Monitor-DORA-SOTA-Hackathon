# Hackathon 3.x Engineering Sequence

This repository uses a visible Hackathon 3.x sequence for mentor review and demo evidence.

## Completed

- **Hackathon 3.0** — Initial System Monitor DORA + SOTA foundation exported from the validated commercial branch. Includes UI, backend, database, AI Ops service, DORA collector, Docker Compose and CI validation.
- **Hackathon 3.1** — Local verification tooling. Adds one-command Windows verification for unit tests, Docker/Compose, four-service startup, health checks, AI anomaly inference and DORA metric calculation.

## Planned sequence

- **Hackathon 3.2** — Terraform AWS foundation: VPC, EKS, ECR, IAM/OIDC baseline.
- **Hackathon 3.3** — CI/CD security pipeline: GitHub OIDC, Trivy gate, SBOM, Cosign signing.
- **Hackathon 3.4** — GitOps: Argo CD auto-sync and deployment history.
- **Hackathon 3.5** — Progressive delivery: Argo Rollouts canary 10% → 25% → 50% → 100% with Prometheus analysis and automatic abort/rollback.
- **Hackathon 3.6** — Policy as Code: Kyverno admission policies and signed-image verification.
- **Hackathon 3.7** — Observability: Prometheus, Grafana, Alertmanager, Loki, Tempo and OpenTelemetry.
- **Hackathon 3.8** — DORA dashboard: Deployment Frequency, Lead Time, Change Failure Rate and MTTR from real events.
- **Hackathon 3.9** — Secrets/TLS: AWS Secrets Manager rotation and cert-manager HTTPS.
- **Hackathon 3.10** — Final end-to-end failure/success demo, evidence pack, report and submission.

## Commit-message rule

All new engineering commits should start with the applicable sequence label, for example:

`Hackathon 3.2 - add Terraform EKS and ECR foundation`

Existing public commits are not force-rewritten because their SHAs are already referenced by validation evidence and changing them would invalidate those links.
