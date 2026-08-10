# Hackathon 3.x Engineering Sequence

This repository uses a simple visible commit sequence for mentor review and demo evidence. Commit titles must progress as `Hackathon 3`, `Hackathon 3.1`, `Hackathon 3.2`, and so on.

## Completed sequence

- **Hackathon 3** — Initial System Monitor DORA + SOTA foundation: UI, backend, database, AI Ops service, DORA collector, Docker Compose and validated CI foundation.
- **Hackathon 3.1** — One-command Windows local verification for unit tests, Docker/Compose, four-service startup, health checks, AI anomaly inference and DORA metric calculation.
- **Hackathon 3.2** — Numbered engineering/version convention for mentor-visible progress.
- **Hackathon 3.3** — Windows PowerShell 5.1 TLS health-check retry fix for the local verification script.
- **Hackathon 3.4** — Repository policy aligned so existing standalone-hackathon commit titles are normalized to the same sequence.

## Planned sequence

- **Hackathon 3.5** — Terraform AWS foundation: VPC, EKS, ECR and IAM/OIDC baseline.
- **Hackathon 3.6** — CI/CD security pipeline: GitHub OIDC, Trivy gate, CycloneDX SBOM and Cosign signing.
- **Hackathon 3.7** — GitOps: Argo CD auto-sync and deployment history.
- **Hackathon 3.8** — Progressive delivery: Argo Rollouts canary 10% → 25% → 50% → 100% with Prometheus analysis and automatic abort/rollback.
- **Hackathon 3.9** — Policy as Code: Kyverno admission policies and signed-image verification.
- **Hackathon 3.10** — Observability: Prometheus, Grafana, Alertmanager, Loki, Tempo and OpenTelemetry.
- **Hackathon 3.11** — DORA dashboard plus Secrets Manager/cert-manager integration and evidence.
- **Hackathon 3.12** — Final end-to-end success/failure demo, evidence pack, report and submission.

## Commit-message rule

Every public engineering commit in this standalone hackathon repository must use the sequence prefix. Examples:

- `Hackathon 3 - Initial System Monitor DORA + SOTA foundation`
- `Hackathon 3.1 - Add one-command local verification`
- `Hackathon 3.2 - Define numbered engineering sequence`

The initial standalone-hackathon history is intentionally normalized to this convention before mentor/final submission review.
