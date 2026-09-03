# 2026-09-03 — AWS Hackathon Teardown Plan

## Goal
Remove the AWS resources created for the System Monitor DORA + SOTA hackathon so ongoing cloud cost stops, while preserving the local Windows System Monitor product and `https://monitor.sagarkerhalkar.com/`.

## Scope
Delete only hackathon AWS resources in `ap-south-1` associated with `sagar-system-monitor` / `sagar-system-monitor-hackathon`.

Expected teardown scope includes:
- Kubernetes application workloads and PVC/PV-backed EBS volumes.
- Amazon EKS cluster and managed worker nodes.
- NAT gateway and VPC networking created by Terraform.
- Hackathon ECR repositories.
- Hackathon KMS key/Secrets Manager metadata as managed by the stack.
- GitHub OIDC role/provider only where owned by this stack; do not delete a shared account-wide OIDC provider blindly.
- Manually created private-EKS SSM helper EC2 instance and its temporary IAM/security-group resources after the cluster is no longer needed.
- Terraform remote-state S3 bucket only after infrastructure destruction and evidence retention are complete.

## Safety boundary
- Do not delete or modify the local Windows production application.
- Do not modify `monitor.sagarkerhalkar.com` DNS/domain routing.
- Do not delete unrelated AWS resources.
- Do not print/commit passwords, keys, tokens or secret plaintext.

## Intended order
1. While private EKS access still exists, delete hackathon Kubernetes workloads/namespaces and wait for PVC/PV cleanup.
2. Run Terraform destroy using the existing remote state.
3. Verify EKS, EC2 worker nodes, NAT gateway, VPC and ECR resources are gone.
4. Remove manually created SSM helper / temporary IAM / security-group leftovers.
5. Remove orphaned EBS volumes/snapshots only if verified as hackathon-owned.
6. Empty all versions/delete markers from the dedicated Terraform state bucket, then delete that bucket.
7. Record final cost-oriented verification in GitHub.

## Source
The repository Terraform README explicitly documents `terraform destroy` as the primary teardown path and notes that the remote-state bucket must be deleted separately after state/evidence are no longer needed.
