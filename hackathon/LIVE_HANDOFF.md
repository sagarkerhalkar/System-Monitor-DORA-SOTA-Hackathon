# System Monitor DORA/SOTA Hackathon — Live Handoff

**Purpose:** Single source of truth for continuing the hackathon in a new ChatGPT chat. Read this file first and continue from **EXACT NEXT STEP** without repeating completed work.

**Last updated:** 2026-08-11 13:40 IST

## Repository

- Repo: `sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon`
- Default branch: `main`
- Live handoff commits:
  - `Hackathon 3.60 - Add live implementation handoff`
  - `Hackathon 3.61 - Record SSM online checkpoint`
  - `Hackathon 3.62 - Record private SSM shell checkpoint`
  - `Hackathon 3.63 - Record kubectl install checkpoint`
- Next numbered implementation commit: **Hackathon 3.64**.

## Locked safety / architecture

- Production System Monitor is separate. Do not modify/deploy `workingcode` without explicit controlled release.
- AWS account: `859934688742`
- Region: `ap-south-1`
- EKS cluster: `sagar-system-monitor-hackathon`
- EKS endpoint is **private-only**. Do not enable public API for convenience.
- Existing AWS infrastructure is chargeable; do not destroy before evidence/submission.

## Completed application / supply-chain proof

- Four-service Phase-1 stack verified: Monitor, UI, AI Ops, DORA.
- Unit tests: 5/5 passed.
- Phase-1 CI passed.
- Supply-chain CI passed end-to-end with Trivy, CycloneDX SBOM, ECR, GitHub OIDC, Cosign signing/attestation/verification.
- Digest-pinned Kubernetes base and Argo CD GitOps bootstrap already merged.
- GitOps CI passed.
- Argo CD bootstrap is pinned to `v3.5.0`.

## Terraform / AWS storage layer — VERIFIED LIVE

- Terraform detailed-exitcode after EBS CSI apply: `0`
- EBS CSI add-on: `ACTIVE`
- Version: `v1.63.1-eksbuild.1`
- Pod Identity association exists.
- IAM role: `sagar-system-monitor-hackathon-ebs-csi`
- Attached policy: `AmazonEBSCSIDriverEKSClusterScopedPolicy`
- Applied resources exactly:
  - `aws_iam_role.ebs_csi`
  - `aws_iam_role_policy_attachment.ebs_csi_cluster_scoped`
  - `aws_eks_addon.ebs_csi`
- No EKS cluster, nodes, NAT, VPC, or ECR recreation occurred.

## Private-cluster access workaround

AWS CloudShell VPC environment could not be created because AWS account verification is still in progress.

Windows `kubectl` must not be used for this private-only cluster; it returned HTML `501 Unsupported method ('GET')`.

Fallback: temporary private Amazon Linux 2023 EC2 management host accessed only through SSM Session Manager. No public IP and no inbound SSH.

## Temporary private EKS admin helper — LIVE

### Network

- VPC: `vpc-0d939b2daac77a161`
- VPC CIDR: `10.42.0.0/16`
- Private subnet: `subnet-07bc456e2735f7255`
- CIDR: `10.42.128.0/20`
- AZ: `ap-south-1a`
- NAT gateway route: `nat-0e681fb5f4bf59f92`

### Security groups

- EKS cluster SG: `sg-06e0da37d74acb793`
- Temporary admin SG: `sg-06294fa8bddcd20ac`
- Admin SG has no inbound rules.
- Temporary EKS ingress allows TCP/443 only from the admin SG.
- Temporary EKS rule ID: `sgr-0d57d869bcc2806e6`

### Temporary IAM / EKS access

- Role + instance profile: `sagar-monitor-hackathon-admin-temp`
- Role ARN: `arn:aws:iam::859934688742:role/sagar-monitor-hackathon-admin-temp`
- Managed policy: `AmazonSSMManagedInstanceCore`
- Inline policy: `sagar-monitor-eks-bootstrap-temp`
- Inline permissions validated for `eks:DescribeCluster`, `eks:DescribeAddon`, `secretsmanager:GetSecretValue`, `secretsmanager:PutSecretValue` scoped to the Monitor admin secret.
- EKS access entry type: `STANDARD`
- Associated access policy: `arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy`
- Scope: cluster
- This access is temporary and must be removed after bootstrap.

### Temporary EC2 helper

- AMI: `ami-0d15e9052c94acb75` (Amazon Linux 2023)
- Instance ID: `i-04747f792cbfdec4d`
- Private IP: `10.42.128.175`
- Instance type: `t3.micro`
- Subnet: `subnet-07bc456e2735f7255`
- SG: `sg-06294fa8bddcd20ac`
- Public IP: none
- IMDSv2 required
- EC2 state: running

### SSM — VERIFIED LIVE

- SSM PingStatus: `Online`
- Platform: `Amazon Linux`
- SSM Agent: `3.3.4624.0`
- Windows Session Manager Plugin installed and working.
- Current shell is an active SSM shell on the helper with prompt `sh-5.2$`.
- AWS identity inside helper verified as:
  `arn:aws:sts::859934688742:assumed-role/sagar-monitor-hackathon-admin-temp/i-04747f792cbfdec4d`

### kubectl — VERIFIED INSTALLED

Initial `kubectl version --client` returned `command not found`.

AWS EKS kubectl was downloaded to `/tmp`, checksum verification passed with:

```text
kubectl: OK
```

Installed to `$HOME/bin/kubectl`; current shell PATH includes `$HOME/bin`.

Verified version:

```text
Client Version: v1.35.3-eks-bbe087e
Kustomize Version: v5.7.1
```

## EXACT NEXT STEP

**Do not redo any setup above. The user is already inside the SSM shell at `sh-5.2$`.**

Continue one command at a time.

Next verify `git` and `openssl` are available:

```bash
git --version && openssl version
```

Then:

1. run `aws eks update-kubeconfig --region ap-south-1 --name sagar-system-monitor-hackathon`;
2. prove `kubectl get nodes -o wide` works from this private instance;
3. clone/pull `sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon`;
4. run `bash gitops/scripts/bootstrap-argocd-cloudshell.sh`;
5. require Argo CD Application `system-monitor` to become `Synced` and `Healthy`;
6. verify pods, PVCs, and services in namespace `system-monitor`.

Do not claim GitOps is deployed until the bootstrap script reports success and resources are healthy.

## Temporary helper cleanup — REQUIRED AFTER ARGO BOOTSTRAP

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

1. Argo Rollouts `v1.9.1` with canary stages 10% -> 25% -> 50% -> 100%.
2. Prometheus analysis gate for AI Ops canary and automatic abort/rollback.
3. DORA deployment/incident/recovery event automation and dashboard.
4. Kyverno policy-as-code with digest pinning and Cosign verification.
5. Prometheus/Grafana/Alertmanager observability; Loki/Tempo/OTel only if time permits.
6. External demo/live URL without exposing EKS API publicly.
7. Intentional bad AI canary -> analysis failure -> rollback -> incident/recovery -> CFR/MTTR update.
8. Final DORA/SOTA report, architecture/evidence, recorded demo, submission.

## New-chat continuation rule

In a new chat say:

> Read `hackathon/LIVE_HANDOFF.md` from `sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon` and continue from EXACT NEXT STEP. Do not repeat completed work.
