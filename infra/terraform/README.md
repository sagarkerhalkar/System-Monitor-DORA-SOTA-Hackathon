# AWS Terraform Foundation

This stack creates the isolated AWS foundation for the **System Monitor DORA + SOTA Hackathon**. It does not deploy or modify the live Windows `workingcode` system.

## What this creates

- VPC across 2 availability zones by default.
- Public subnets for the NAT gateway and future internet-facing load balancers, with automatic public-IP assignment disabled.
- Private subnets for Amazon EKS managed nodes.
- One NAT gateway to reduce hackathon cost while keeping worker nodes private.
- Amazon EKS cluster with Kubernetes 1.36 by default.
- **Private-only EKS Kubernetes API endpoint**; it is not reachable from the public internet.
- EKS control-plane logs with 7-day retention.
- Customer-managed rotating KMS key.
- Kubernetes secret encryption with the KMS key.
- Two-node on-demand managed node group by default.
- Core EKS add-ons: VPC CNI, kube-proxy, CoreDNS and EKS Pod Identity Agent.
- Four private ECR repositories: Monitor, UI, AI Ops and DORA Collector.
- Immutable ECR tags, scan-on-push, KMS encryption and image lifecycle cleanup.
- GitHub Actions OIDC provider/role restricted to this repository's main branch or `production` GitHub Environment.
- KMS-encrypted Secrets Manager metadata for Monitor admin, DORA webhook HMAC and Grafana admin credentials.
- No application secret values are stored in Terraform source.

## Safety and cost guardrails

The EKS Kubernetes API is private-only. Management commands such as `kubectl` must run from inside the VPC or a connected network. For this hackathon, the supported operator path is the **Amazon EKS console → Connect → AWS CloudShell** flow, which launches a CloudShell VPC environment for a private cluster.

The default node group uses two `t3.large` on-demand instances because the final stack will include Argo CD, Argo Rollouts, Prometheus, Grafana, Loki, Tempo, OpenTelemetry, Kyverno and the four application services. You can override the instance type and capacity type in `terraform.tfvars`, but do not reduce capacity until the full observability stack has been tested.

The stack uses one NAT gateway rather than one per availability zone to reduce short-lived hackathon cost. This is an intentional demo/cost tradeoff, not the recommended high-availability production topology.

EKS support type is `STANDARD`, not `EXTENDED`, so an old cluster version does not silently move into the higher-cost extended-support tier.

## Prerequisites

Install or have access to:

- AWS CLI v2 authenticated to the hackathon AWS account.
- Terraform 1.10+; CI currently validates with Terraform 1.15.5.
- Git.
- AWS Management Console access for the private-cluster CloudShell connection flow.

Never paste AWS access keys into chat, source files, Terraform variables, GitHub repository secrets or shell scripts. Prefer AWS IAM Identity Center/SSO, an existing administrator role, or AWS CloudShell for the initial bootstrap. GitHub Actions will use OIDC and short-lived AWS credentials.

## 1. Confirm AWS identity

```powershell
aws sts get-caller-identity
```

Record the account ID for your own reference. Do not change any production AWS account resources outside this hackathon stack.

## 2. Check whether GitHub OIDC already exists

```powershell
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text
```

If this returns nothing, leave:

```hcl
create_github_oidc_provider = true
```

If it returns an ARN, set:

```hcl
create_github_oidc_provider        = false
existing_github_oidc_provider_arn = "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
```

This avoids attempting to create the account-wide GitHub OIDC provider twice.

## 3. Create remote Terraform state

From the repository root:

```powershell
Set-Location .\infra\terraform
Set-ExecutionPolicy -Scope Process Bypass -Force
& .\scripts\bootstrap-state.ps1
```

The script creates an account/region-unique S3 bucket when needed, blocks all public access, enables versioning, enables server-side encryption, and writes the ignored `backend.hcl` file.

Then enable the checked-in backend template:

```powershell
Copy-Item .\backend.tf.example .\backend.tf
terraform init -backend-config=backend.hcl
```

The backend uses S3 native state locking (`use_lockfile = true`); no DynamoDB locking table is required.

## 4. Create local variables

```powershell
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Review `terraform.tfvars`. The default is a private-only EKS Kubernetes API, so no public API CIDR is configured.

`terraform.tfvars`, `backend.hcl`, plans and state files are ignored by Git.

## 5. Validate before spending AWS money

```powershell
terraform fmt -recursive
terraform validate
terraform plan -out=hackathon.tfplan
```

Read the plan before applying. Confirm that all names/tags contain `sagar-system-monitor` / `hackathon`, EKS public endpoint access is disabled, worker subnets are private, and public subnets do not auto-assign public IP addresses.

## 6. Apply

```powershell
terraform apply hackathon.tfplan
terraform output
```

Do not call the infrastructure ready merely because `terraform apply` completes. The node readiness check happens from the private-cluster CloudShell connection.

## 7. Connect to the private cluster

In the AWS Management Console:

1. Open **Amazon EKS**.
2. Open cluster `sagar-system-monitor-hackathon`.
3. Choose **Connect**.
4. Launch the offered **AWS CloudShell** connection. For a private cluster, AWS creates/uses a CloudShell VPC environment that can reach the private Kubernetes API endpoint.
5. In CloudShell run:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

All expected managed nodes must be `Ready` before proceeding to Argo CD/GitOps installation.

A local `aws eks update-kubeconfig` command can create kubeconfig metadata, but a normal internet-connected laptop cannot reach this private Kubernetes API unless it also has VPC network connectivity. Do not re-enable the public endpoint just for convenience.

## 8. Secret values

Terraform creates secret metadata only. The real values will be generated/populated in the Secrets Manager + External Secrets phase so secret plaintext does not enter Terraform state. Rotation will also be implemented and demonstrated there.

## 9. Teardown after submission/evidence

Keep the infrastructure only while the hackathon demo/evidence needs it. After submission evidence is safely stored:

```powershell
terraform destroy
```

Confirm the EKS cluster, EC2 nodes, load balancers, NAT gateway and ECR resources are removed. The remote-state bucket is intentionally separate; retain it until final evidence/recovery is no longer needed, then remove its object versions and bucket explicitly.

## Current boundary

This Terraform foundation creates infrastructure only. Argo CD, Argo Rollouts, Prometheus/Grafana, Loki/Tempo/OpenTelemetry, Kyverno, cert-manager, runtime secret rotation and application Kubernetes workloads are added in subsequent numbered hackathon commits.
