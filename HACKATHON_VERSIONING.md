# Hackathon 3.x Engineering Sequence

This repository uses a simple visible commit sequence for mentor review and demo evidence. Public engineering commit titles progress as `Hackathon 3`, `Hackathon 3.1`, `Hackathon 3.2`, and so on.

## Completed sequence

- **Hackathon 3** — Initial System Monitor DORA + SOTA foundation: UI, backend, database, AI Ops, DORA collector, Docker Compose and CI foundation.
- **Hackathon 3.1** — Add one-command local verification.
- **Hackathon 3.2** — Define numbered engineering sequence.
- **Hackathon 3.3** — Fix Windows TLS health-check retry.
- **Hackathon 3.4** — Align repository commit numbering policy.
- **Hackathon 3.5** — Use Python TLS probe and print Monitor diagnostics on failure.
- **Hackathon 3.6** — Enforce LF line endings for Linux scripts.
- **Hackathon 3.7** — Renormalize Monitor Linux entrypoint.
- **Hackathon 3.8** — Allow passwordless image builds while preserving runtime bootstrap guard.
- **Hackathon 3.9** — Use Python for all local HTTP probes.
- **Hackathon 3.10** — Verify container health and published ports without Windows HTTP proxy dependence.
- **Hackathon 3.11** — Ignore local Python cache artifacts.
- **Hackathon 3.12** — Stream container smoke tests through stdin to avoid PowerShell quoting.
- **Hackathon 3.13** — Align local verifier with AI and DORA response contracts. Physical Windows verification reached `ALL PHASE-1 CHECKS PASSED`.
- **Hackathon 3.14** — Pin Terraform and AWS provider baseline.
- **Hackathon 3.15** — Add AWS provider and account discovery.
- **Hackathon 3.16** — Define safe cost-conscious AWS inputs.
- **Hackathon 3.17** — Define AWS naming, subnets, ECR and GitHub OIDC subjects.
- **Hackathon 3.18** — Add two-AZ VPC with private EKS subnets and one NAT gateway.
- **Hackathon 3.19** — Add EKS control-plane and managed-node IAM roles.
- **Hackathon 3.20** — Add rotating KMS key for hackathon platform encryption.
- **Hackathon 3.21** — Add encrypted EKS 1.36 cluster, managed nodes and core add-ons.
- **Hackathon 3.22** — Add immutable encrypted scanned ECR repositories and cleanup policies.
- **Hackathon 3.23** — Add repository-scoped GitHub OIDC role for keyless AWS access.
- **Hackathon 3.24** — Add KMS-encrypted Secrets Manager metadata without storing secret values.
- **Hackathon 3.25** — Expose EKS, ECR, OIDC, KMS and secret integration outputs.
- **Hackathon 3.26** — Add secret-free AWS tfvars example and initial EKS endpoint guardrail.
- **Hackathon 3.27** — Ignore Terraform secrets, plans, state and backend runtime files.
- **Hackathon 3.28** — Add S3 remote-state lockfile backend template.
- **Hackathon 3.29** — Add idempotent encrypted S3 Terraform state bootstrap.
- **Hackathon 3.30** — Document safe AWS bootstrap, apply, validation and teardown workflow.
- **Hackathon 3.31** — Add Terraform validation and Trivy IaC security gate.
- **Hackathon 3.32** — Synchronize mentor-visible engineering/version ledger with delivered work.
- **Hackathon 3.33** — Fix Terraform runtime-file guard and pin CI action SHAs.
- **Hackathon 3.34** — Format Terraform VPC configuration.
- **Hackathon 3.35** — Print Terraform formatter diff in CI.
- **Hackathon 3.36** — Apply exact Terraform VPC formatting.
- **Hackathon 3.37** — Make EKS Kubernetes API private-only.
- **Hackathon 3.38** — Disable automatic public IPs on public subnets.
- **Hackathon 3.39** — Remove obsolete public EKS endpoint CIDR input.
- **Hackathon 3.40** — Simplify tfvars for private-only EKS access.
- **Hackathon 3.41** — Document private EKS CloudShell management workflow. Terraform CI passed format, provider init, validate and Trivy HIGH/CRITICAL with no suppressed findings.
- **Hackathon 3.42** — Synchronize the version ledger after the validated AWS Terraform foundation merge.

## Next sequence

- **Hackathon 3.43** — Container CI/CD supply-chain pipeline: AWS OIDC, ECR build/push by digest, Trivy HIGH/CRITICAL image gate, CycloneDX SBOM and Cosign keyless signing/attestation.
- **Hackathon 3.44** — Kubernetes base manifests and GitOps repository structure.
- **Hackathon 3.45** — Argo CD install/application with auto-sync, prune, self-heal and visible deployment history.
- **Hackathon 3.46** — Argo Rollouts canary 10% → 25% → 50% → 100% with Prometheus analysis and automatic abort/rollback.
- **Hackathon 3.47** — Kyverno policy as code including non-root, resources, allowed registry/digest and signed-image verification.
- **Hackathon 3.48** — Prometheus, Grafana and Alertmanager observability.
- **Hackathon 3.49** — Loki logs, Tempo traces and OpenTelemetry instrumentation/collection.
- **Hackathon 3.50** — DORA dashboard and CI/rollout/incident event integration.
- **Hackathon 3.51** — Secrets Manager runtime integration, rotation, cert-manager and HTTPS.
- **Hackathon 3.52** — Deliberately bad canary, automated rollback, MTTR evidence and policy-denial demo.
- **Hackathon 3.53** — Final DORA + SOTA report, architecture, evidence pack, demo script and submission package.

## Commit-message rule

Every public engineering commit in this standalone hackathon repository uses the sequence prefix. Do not use generic messages such as `Initial project`, `update`, `fix`, or raw source-SHA provenance as the visible commit title.

## Current live continuation

- **Hackathon 3.80** - Align secure Monitor bootstrap password policy; live Monitor recovered and Argo CD reached `Synced` + `Healthy`.
- **Hackathon 3.81** - Add pinned, checksum-verified, idempotent Argo Rollouts v1.9.1 foundation with CI and permanent PASS/FAIL evidence policy.
- **Hackathon 3.82** - COMPLETE: AI Ops converted to a 20-replica Argo Rollout and live staged canary `10% -> 25% -> 50% -> 100%` was proven with the final revision stable and permanent evidence stored in GitHub.
- **Hackathon 3.83** - IN PROGRESS: correct the mentor/product architecture by rebasing future hackathon work onto the user's real System Monitor product UI and backend served from the local Windows server at `https://monitor.sagarkerhalkar.com/`. The separate `hackathon/ui` dashboard is supporting DevOps evidence only. First gate: capture and inspect the exact current live source without changing production or exposing secrets. After the real product is mirrored safely into the isolated hackathon track, continue Prometheus automated analysis/abort/rollback on the same real product code/image.
