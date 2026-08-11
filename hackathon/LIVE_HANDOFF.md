# System Monitor DORA/SOTA Hackathon — Live Handoff

**Purpose:** Single source of truth for continuing the hackathon in a new ChatGPT chat. Read this file first and continue from **EXACT NEXT STEP** without repeating completed work.

**Last updated:** 2026-08-11 16:29 IST

## Repository

- Repo: `sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon`
- Default branch: `main`
- Permanent command/evidence log: `hackathon/COMMAND_AND_EVIDENCE_LOG.md`
- Important recent commits:
  - `Hackathon 3.60 - Add live implementation handoff`
  - `Hackathon 3.61 - Record SSM online checkpoint`
  - `Hackathon 3.62 - Record private SSM shell checkpoint`
  - `Hackathon 3.63 - Record kubectl install checkpoint`
  - `Hackathon 3.64 - Record EKS kubeconfig checkpoint`
  - `Hackathon 3.65 - Record private EKS connectivity checkpoint`
  - `Hackathon 3.66 - Record helper repository clone checkpoint`
  - `Hackathon 3.67 - Record KMS bootstrap permission fix`
  - `Hackathon 3.68 - Fix Kubernetes monitor port collision` — `fd0ab5cc3d3c33bfd39117b531fa06d08dc23a03`
  - `Hackathon 3.69 - Update Monitor signed image digest` — `3d6c8241c5d2dad7d5f4227ba10fc9ef33814e60`
  - `Hackathon 3.70 - Add command and evidence log` — `57ba705ba5ed4d68841ab021419ba1ecb4a21cdb`
  - `Hackathon 3.71 - Update live handoff after Monitor fix` — this update
- Next numbered implementation commit after this handoff: **Hackathon 3.72**.

## Documentation rule — LOCKED

From now on every meaningful live command must be recorded in `hackathon/COMMAND_AND_EVIDENCE_LOG.md` with:

- date/time or checkpoint
- exact command when captured
- purpose
- important output
- result: SUCCESS / FAILED / EXPECTED ERROR / IN PROGRESS
- what the output means
- next action

Record useful failed commands as well as successful commands. Never record secret values, passwords, tokens, or private keys. Never claim a test/deployment passed without evidence.

## Locked safety / architecture

- Production System Monitor is separate. Do not modify/deploy `workingcode` without explicit controlled release.
- AWS account: `859934688742`
- Region: `ap-south-1`
- EKS cluster: `sagar-system-monitor-hackathon`
- EKS endpoint is **private-only**. Do not enable public API for convenience.
- Existing AWS infrastructure is chargeable; do not destroy before evidence/submission.

## Completed application / supply-chain proof

- Four-service Phase-1 stack verified locally: Monitor, UI, AI Ops, DORA.
- Unit tests: 5/5 passed.
- Phase-1 CI passed.
- Supply-chain CI passed end-to-end with Trivy, CycloneDX SBOM, ECR, GitHub OIDC, Cosign signing/attestation/verification.
- Digest-pinned Kubernetes base and Argo CD GitOps bootstrap merged.
- GitOps CI passed.
- Argo CD bootstrap pinned to `v3.5.0`.

## Terraform / AWS storage layer — VERIFIED LIVE

- Terraform detailed-exitcode after EBS CSI apply: `0`
- EBS CSI add-on: `ACTIVE`
- Version: `v1.63.1-eksbuild.1`
- Pod Identity association exists.
- IAM role: `sagar-system-monitor-hackathon-ebs-csi`
- Attached policy: `AmazonEBSCSIDriverEKSClusterScopedPolicy`
- No EKS cluster, nodes, NAT, VPC, or ECR recreation occurred.

## Private-cluster access workaround

AWS CloudShell VPC environment could not be created because AWS account verification was still in progress.

Windows `kubectl` was not usable for this private-only cluster and returned HTML `501 Unsupported method ('GET')`.

Fallback: temporary private Amazon Linux 2023 EC2 management host accessed only through SSM Session Manager. No public IP and no inbound SSH.

## Temporary private EKS admin helper — LIVE

### Network

- VPC: `vpc-0d939b2daac77a161`
- Private subnet: `subnet-07bc456e2735f7255`
- CIDR: `10.42.128.0/20`
- AZ: `ap-south-1a`
- NAT gateway route: `nat-0e681fb5f4bf59f92`
- EKS cluster SG: `sg-06e0da37d74acb793`
- Temporary admin SG: `sg-06294fa8bddcd20ac`
- Temporary EKS rule: `sgr-0d57d869bcc2806e6`, TCP/443 from temp admin SG only.

### IAM / EKS access

- Role + instance profile: `sagar-monitor-hackathon-admin-temp`
- Role ARN: `arn:aws:iam::859934688742:role/sagar-monitor-hackathon-admin-temp`
- Managed policy: `AmazonSSMManagedInstanceCore`
- Inline policy: `sagar-monitor-eks-bootstrap-temp`
- KMS actions temporarily added: `kms:GenerateDataKey`, `kms:Decrypt`
- KMS scope only: `arn:aws:kms:ap-south-1:859934688742:key/2e010c48-d182-4084-80be-1e70db88cb60`
- EKS access entry type: `STANDARD`
- Associated EKS policy: `AmazonEKSClusterAdminPolicy`, cluster scope.
- This entire helper access is temporary and must be removed after GitOps evidence is complete.

### EC2 / SSM

- Instance: `i-04747f792cbfdec4d`
- Private IP: `10.42.128.175`
- Type: `t3.micro`
- AMI: Amazon Linux 2023 `ami-0d15e9052c94acb75`
- No public IP
- IMDSv2 required
- SSM PingStatus: `Online`
- Verified identity: `arn:aws:sts::859934688742:assumed-role/sagar-monitor-hackathon-admin-temp/i-04747f792cbfdec4d`

### Helper tools

- kubectl `v1.35.3-eks-bbe087e`
- Kustomize `v5.7.1`
- git `2.50.1`
- OpenSSL `3.5.7 9 Jun 2026`

## Private EKS API — VERIFIED

Exact kubeconfig command succeeded:

```bash
aws eks update-kubeconfig --region ap-south-1 --name sagar-system-monitor-hackathon
```

Two worker nodes are `Ready` with no external IP:

- `ip-10-42-137-89.ap-south-1.compute.internal`, internal IP `10.42.137.89`
- `ip-10-42-153-66.ap-south-1.compute.internal`, internal IP `10.42.153.66`

## First Argo bootstrap — FAILED SAFELY AT KMS

`bash gitops/scripts/bootstrap-argocd-cloudshell.sh` passed identity, private API, nodes, EBS CSI, and namespace preparation, then stopped with:

```text
An error occurred (AccessDeniedException) when calling the PutSecretValue operation: Access to KMS is not allowed
```

The temporary role was then given only the required `kms:GenerateDataKey` and `kms:Decrypt` actions on the exact platform KMS key.

## Second Argo bootstrap — GITOPS WORKED, WORKLOAD HEALTH FAILED

The retry successfully:

- stored/generated the Monitor admin password in Secrets Manager
- created Kubernetes secret `monitor-runtime`
- installed Argo CD v3.5.0
- completed argocd-server, repo-server, applicationset-controller rollouts
- created AppProject and Application
- completed Argo sync operation successfully

Argo became `Synced`, but health progressed to `Degraded` because Monitor entered CrashLoopBackOff. AI Ops, DORA, and UI were running. Both EBS PVCs were `Bound`.

## Monitor CrashLoopBackOff — ROOT CAUSE PROVEN

Previous Monitor logs returned:

```text
{"error": "server configuration is not valid JSON", "ok": false}
```

Source tracing found `load_server_config(arguments.config)` in the commercial CLI.

Kubernetes did not override pod command/args, proving the image ENTRYPOINT was used.

Direct `kubectl exec` failed because the Monitor container died too quickly:

```text
error: unable to upgrade connection: container not found ("monitor")
```

A temporary read-only inspection pod mounted the `monitor-data` PVC. Reading `/inspect/server.json` proved the exact malformed field:

```text
"port": tcp://172.20.177.2:8443,
```

### Exact root cause

The Kubernetes Service is named `monitor`. Kubernetes service links automatically injected a `MONITOR_PORT` environment variable containing a service URL such as:

```text
tcp://172.20.177.2:8443
```

The Monitor entrypoint also used `MONITOR_PORT` as its numeric application listen port, so it generated invalid JSON.

The diagnostic pod was then deleted successfully so it no longer held the EBS volume.

## Hackathon 3.68 — PORT COLLISION FIX

Commit:

```text
fd0ab5cc3d3c33bfd39117b531fa06d08dc23a03
```

The entrypoint now prefers `MONITOR_LISTEN_PORT`, validates numeric input, and safely falls back to 8443 if Kubernetes injects a non-numeric service URL through `MONITOR_PORT`.

For this commit:

```text
Hackathon Phase 1 CI              completed success
Hackathon Container Supply Chain completed success
```

Run IDs:

```text
31483388324  Hackathon Phase 1 CI
31483388301  Hackathon Container Supply Chain
```

Corrected signed Monitor image:

```text
859934688742.dkr.ecr.ap-south-1.amazonaws.com/sagar-system-monitor/monitor@sha256:4bd4abf6f7fcfe7bc7c325f4b00b1562a4714961fb252a1f97b496ea276dfb24
```

## Hackathon 3.69 — GITOPS DIGEST UPDATED

Commit:

```text
3d6c8241c5d2dad7d5f4227ba10fc9ef33814e60
```

Only the Monitor image digest was changed in `gitops/base/system-monitor.yaml`. AI Ops, DORA, UI, PVCs, services, and production were not changed.

## CURRENT LIVE ARGO STATE

Latest exact command:

```bash
kubectl -n argocd get application system-monitor -o wide
```

Latest exact output:

```text
NAME             SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
system-monitor   Synced        Progressing     3d6c8241c5d2dad7d5f4227ba10fc9ef33814e60   system-monitor
```

### Interpretation

- Argo CD has detected and synced Hackathon 3.69.
- The corrected signed Monitor digest is now the desired GitOps state.
- Health is still `Progressing`.
- **Do not claim full GitOps success yet.**

## EXACT NEXT STEP

The user is already at the helper prompt `sh-5.2$` in `~/System-Monitor-DORA-SOTA-Hackathon`.

Run exactly:

```bash
kubectl -n system-monitor get pods -o wide
```

Purpose: verify whether the new Monitor pod using the corrected signed digest becomes `1/1 Running` and check all other workload pods.

If Monitor is not healthy, inspect its current/previous logs and pod events. If all pods are healthy, check the Argo Application again and require `Synced` + `Healthy`, then rerun/complete bootstrap evidence.

Every command/output from this point must also be appended to `hackathon/COMMAND_AND_EVIDENCE_LOG.md`.

## Temporary helper cleanup — REQUIRED AFTER ARGO HEALTHY EVIDENCE

After Argo CD and System Monitor are proven healthy:

1. terminate EC2 `i-04747f792cbfdec4d`;
2. disassociate the EKS cluster-admin policy from the temp role;
3. delete the EKS access entry;
4. revoke EKS SG rule `sgr-0d57d869bcc2806e6`;
5. delete temp SG `sg-06294fa8bddcd20ac`;
6. remove role from instance profile;
7. delete instance profile `sagar-monitor-hackathon-admin-temp`;
8. delete inline policy `sagar-monitor-eks-bootstrap-temp`;
9. detach `AmazonSSMManagedInstanceCore`;
10. delete IAM role `sagar-monitor-hackathon-admin-temp`.

Do not delete the permanent EBS CSI role/add-on.

## Remaining hackathon sequence after GitOps

1. Argo Rollouts `v1.9.1` with canary 10% -> 25% -> 50% -> 100%.
2. Prometheus analysis gate and automatic abort/rollback for a bad AI Ops canary.
3. DORA deployment/incident/recovery automation and dashboard.
4. Kyverno policy-as-code: digest/non-root/restricted plus Cosign verification.
5. Prometheus/Grafana/Alertmanager; Loki/Tempo/OTel only if time permits.
6. External demo URL without making EKS API public.
7. Intentional bad AI canary -> failure -> rollback -> incident/recovery -> CFR/MTTR evidence.
8. Final DORA/SOTA report, architecture/evidence, demo recording, submission.

## New-chat continuation rule

In a new chat say:

> Read `hackathon/LIVE_HANDOFF.md` and `hackathon/COMMAND_AND_EVIDENCE_LOG.md` from `sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon` and continue from EXACT NEXT STEP. Do not repeat completed work.
