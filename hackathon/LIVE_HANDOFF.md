# System Monitor DORA/SOTA Hackathon — Live Handoff

**Purpose:** This is the single source of truth for continuing the hackathon in a new ChatGPT chat. Read this file first before giving commands or making changes.

**Last updated:** 2026-08-11 13:25 IST

## Repository

- Repo: `sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon`
- Default branch: `main`
- Previous implementation sequence was through `Hackathon 3.59`.
- `Hackathon 3.60 - Add live implementation handoff` created this file.
- `Hackathon 3.61 - Record SSM online checkpoint` records the current live AWS checkpoint.
- Next numbered implementation commit after this checkpoint is **Hackathon 3.62**.

## Locked architecture / safety

- Production System Monitor is separate. Do not modify or deploy `workingcode` without an explicit controlled release.
- Hackathon AWS region: `ap-south-1`.
- AWS account: `859934688742`.
- EKS cluster: `sagar-system-monitor-hackathon`.
- EKS endpoint is **private-only**. Do not enable the public EKS API for convenience.
- Existing infrastructure is chargeable; do not destroy before evidence/submission.

## Completed before current session

### Phase 1 application proof

- Four-service local stack verified earlier: Monitor, UI, AI Ops, DORA.
- Unit tests: 5/5 passed.
- Phase-1 CI passed.
- Supply-chain CI passed end-to-end with Trivy, SBOM, ECR, GitHub OIDC, Cosign signing and verification.
- Digest-pinned Kubernetes base and Argo CD GitOps bootstrap are already merged to `main`.

### GitOps code already merged

- `gitops/base/system-monitor.yaml`
- `gitops/argocd/bootstrap.yaml`
- `gitops/scripts/bootstrap-argocd-cloudshell.sh`
- `.github/workflows/hackathon-gitops-ci.yml`
- Argo CD pinned version in bootstrap: `v3.5.0`
- GitOps CI passed after `Hackathon 3.59`.

## Terraform / AWS storage layer — VERIFIED LIVE

EBS CSI Terraform was applied successfully and then verified with a zero-drift plan.

- Terraform detailed-exitcode after apply: `0`
- EBS CSI add-on: `ACTIVE`
- EBS CSI version: `v1.63.1-eksbuild.1`
- Pod Identity association exists.
- IAM role: `sagar-system-monitor-hackathon-ebs-csi`
- Attached policy: `AmazonEBSCSIDriverEKSClusterScopedPolicy`

The applied resources were exactly:

- `aws_iam_role.ebs_csi`
- `aws_iam_role_policy_attachment.ebs_csi_cluster_scoped`
- `aws_eks_addon.ebs_csi`

No EKS cluster, nodes, NAT, VPC, or ECR recreation occurred.

## Why CloudShell was not used

AWS CloudShell VPC environment creation failed because AWS account verification is still in progress and the console said verification may take up to two days.

Windows `kubectl` must not be used for this private-only cluster. It returned HTML `501 Unsupported method ('GET')`, showing the request was hitting a proxy/web path rather than the Kubernetes API.

Fallback chosen: a temporary private Amazon Linux EC2 management host using SSM Session Manager, no public IP, no inbound SSH.

## Temporary private EKS admin helper — CURRENT STATE

### VPC / subnet

- VPC: `vpc-0d939b2daac77a161`
- VPC CIDR: `10.42.0.0/16`
- Private subnet selected: `subnet-07bc456e2735f7255`
- Private subnet CIDR: `10.42.128.0/20`
- AZ: `ap-south-1a`
- Private subnet has active default route through NAT gateway `nat-0e681fb5f4bf59f92`.

### Security groups

- EKS cluster security group: `sg-06e0da37d74acb793`
- Temporary admin security group: `sg-06294fa8bddcd20ac`
- Temporary admin SG was created with no inbound rules.
- EKS cluster SG received one temporary ingress rule allowing TCP/443 **only from** `sg-06294fa8bddcd20ac`.
- Temporary rule ID: `sgr-0d57d869bcc2806e6`

### Temporary IAM role / profile

Role:

- `sagar-monitor-hackathon-admin-temp`
- ARN: `arn:aws:iam::859934688742:role/sagar-monitor-hackathon-admin-temp`

Instance profile:

- `sagar-monitor-hackathon-admin-temp`

Attached managed policy:

- `AmazonSSMManagedInstanceCore`

Inline policy:

- `sagar-monitor-eks-bootstrap-temp`

Validated inline permissions include:

- `eks:DescribeCluster`
- `eks:DescribeAddon`
- `secretsmanager:GetSecretValue`
- `secretsmanager:PutSecretValue`

Secret scope:

- `arn:aws:secretsmanager:ap-south-1:859934688742:secret:/sagar-system-monitor/hackathon/monitor-admin-password-*`

### EKS access entry for temporary role

Access entry created for:

- `arn:aws:iam::859934688742:role/sagar-monitor-hackathon-admin-temp`
- Type: `STANDARD`

Associated access policy:

- `arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy`
- Scope: `cluster`

This is temporary and must be removed after bootstrap.

### Temporary EC2 helper

AMI:

- `ami-0d15e9052c94acb75` (Amazon Linux 2023)

Temporary EC2:

- Instance ID: `i-04747f792cbfdec4d`
- Private IP: `10.42.128.175`
- Instance type: `t3.micro`
- Subnet: `subnet-07bc456e2735f7255`
- Security group: `sg-06294fa8bddcd20ac`
- Instance profile: `sagar-monitor-hackathon-admin-temp`
- Public IP: none
- IMDSv2 required
- Tag Name: `sagar-monitor-hackathon-admin-temp`
- EC2 state: `running`

### SSM registration — VERIFIED LIVE

The following command was run successfully from Windows PowerShell:

```powershell
aws ssm describe-instance-information --region ap-south-1 --filters Key=InstanceIds,Values=i-04747f792cbfdec4d --query "InstanceInformationList[].{InstanceId:InstanceId,PingStatus:PingStatus,Platform:PlatformName,AgentVersion:AgentVersion}" --output table
```

Verified result:

- Instance ID: `i-04747f792cbfdec4d`
- PingStatus: `Online`
- Platform: `Amazon Linux`
- SSM Agent version: `3.3.4624.0`

## EXACT NEXT STEP

Do not redo any setup above.

From the user's normal Windows PowerShell, open an SSM Session Manager shell to the private helper:

```powershell
aws ssm start-session --region ap-south-1 --target i-04747f792cbfdec4d
```

Desired result is an interactive shell on the Amazon Linux helper, not a Windows `PS C:\...>` prompt.

Once the SSM shell opens, continue one command at a time:

1. prove AWS identity is the temporary role with `aws sts get-caller-identity`;
2. verify/install `kubectl`, `git`, and `openssl` as needed;
3. run `aws eks update-kubeconfig --region ap-south-1 --name sagar-system-monitor-hackathon`;
4. prove `kubectl get nodes -o wide` works from the private instance;
5. clone/pull `sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon`;
6. run `bash gitops/scripts/bootstrap-argocd-cloudshell.sh` (despite the filename, it can run from this private management host because it only requires AWS + kubectl + openssl + network reachability);
7. require Argo CD Application `system-monitor` to become `Synced` and `Healthy`;
8. verify pods, PVCs, and services in namespace `system-monitor`.

Do not claim GitOps is deployed until the bootstrap script reports success and the resources are healthy.

## Temporary helper cleanup — REQUIRED AFTER ARGO BOOTSTRAP

After Argo CD and System Monitor are proven healthy, remove temporary access carefully:

1. terminate EC2 `i-04747f792cbfdec4d`;
2. delete EKS access-policy association for the temp role;
3. delete EKS access entry for the temp role;
4. revoke EKS SG rule `sgr-0d57d869bcc2806e6`;
5. delete temporary SG `sg-06294fa8bddcd20ac`;
6. remove role from instance profile;
7. delete instance profile `sagar-monitor-hackathon-admin-temp`;
8. delete inline policy `sagar-monitor-eks-bootstrap-temp`;
9. detach `AmazonSSMManagedInstanceCore`;
10. delete IAM role `sagar-monitor-hackathon-admin-temp`.

Do not delete the EBS CSI role/add-on; those are permanent hackathon infrastructure.

## Remaining hackathon sequence after GitOps deployment

1. Argo Rollouts `v1.9.1` with canary stages 10% -> 25% -> 50% -> 100%.
2. Prometheus analysis gate for AI Ops canary and automatic abort/rollback.
3. DORA deployment/incident/recovery event automation and dashboard.
4. Kyverno policy-as-code including digest pinning and Cosign verification.
5. Observability stack: Prometheus/Grafana/Alertmanager; Loki/Tempo/OTel only if time permits.
6. External demo/live URL without exposing the EKS API publicly.
7. Intentional bad AI canary demo -> analysis failure -> rollback -> incident/recovery -> CFR/MTTR update.
8. Final DORA/SOTA report, architecture/evidence, recorded demo, submission.

## Continuation rule for any new ChatGPT chat

The user should say:

> Read `hackathon/LIVE_HANDOFF.md` from `sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon` and continue from EXACT NEXT STEP. Do not repeat completed work.

The assistant should fetch this file from GitHub before giving new commands.
