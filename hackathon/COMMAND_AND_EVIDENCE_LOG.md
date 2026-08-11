# System Monitor DORA/SOTA Hackathon — Command and Evidence Log

**Purpose:** Permanent chronological record of the commands used during the AWS/EKS/GitOps hackathon implementation, what each command does, the important output, whether it succeeded or failed, and what was done next.

**Scope:** Work captured from the private EKS bring-up, temporary SSM management host, Argo CD bootstrap, KMS permission failure, Monitor CrashLoopBackOff diagnosis, and the GitOps image correction through 2026-08-11.

> Security rule: passwords, secret values, credentials, tokens, and private key contents are intentionally never recorded here.

## How to read this log

- **Command** — what was run.
- **Purpose** — why it was run.
- **Important output** — exact captured output where available; otherwise a clearly marked verified summary from the live checkpoint.
- **Result** — `SUCCESS`, `EXPECTED ERROR`, `FAILED`, or `IN PROGRESS`.
- **Meaning / next action** — what the result told us and why the following step was taken.

Some earlier commands were reconstructed from the verified live handoff because the complete terminal transcript was not retained. Those are marked **reconstructed from verified checkpoint** rather than falsely presented as exact transcript text.

---

# 1. Connect to the private AWS management host

## 1.1 Start SSM Session Manager from Windows

**Command — exact reconnect command retained in the live handoff**

```powershell
$env:Path="$env:ProgramFiles\Amazon\SessionManagerPlugin\bin;$env:Path"; aws ssm start-session --region ap-south-1 --target i-04747f792cbfdec4d
```

**Purpose**

Open a shell on the temporary Amazon Linux 2023 EC2 helper without exposing SSH or assigning a public IP. This host exists inside the VPC so it can reach the private-only EKS API.

**Important output — verified checkpoint**

```text
sh-5.2$
```

**Result:** SUCCESS

**Meaning / next action**

We gained private administrative access through AWS Systems Manager. The EKS API itself remained private.

### Error seen when region was omitted

**Command pattern that failed**

```powershell
aws ssm start-session --target i-04747f792cbfdec4d
```

**Important output**

```text
NoRegion
```

**Result:** EXPECTED ERROR / CONFIGURATION ERROR

**Meaning / fix**

The AWS CLI had no default region configured for that shell. Adding `--region ap-south-1` fixed it.

---

# 2. Restore helper-shell tools

## 2.1 Put the previously installed kubectl in PATH

**Command**

```bash
export PATH="$HOME/bin:$PATH"
```

**Purpose**

Make `$HOME/bin/kubectl` available in a fresh SSM session.

**Important output**

No output is expected when successful.

**Result:** SUCCESS

**Verified tool versions**

```text
kubectl v1.35.3-eks-bbe087e
Kustomize v5.7.1
git 2.50.1
OpenSSL 3.5.7 9 Jun 2026
```

---

# 3. Verify AWS identity from the private helper

## 3.1 Check the active IAM identity

**Command — reconstructed from verified checkpoint**

```bash
aws sts get-caller-identity
```

**Purpose**

Confirm that the EC2 instance was using the intended temporary bootstrap IAM role rather than a personal credential or another role.

**Important output — verified identity**

```text
arn:aws:sts::859934688742:assumed-role/sagar-monitor-hackathon-admin-temp/i-04747f792cbfdec4d
```

**Result:** SUCCESS

**Meaning**

The private helper was authenticated through the temporary role `sagar-monitor-hackathon-admin-temp`.

---

# 4. Build Kubernetes access to the private EKS cluster

## 4.1 Create/update kubeconfig

**Command — exact**

```bash
aws eks update-kubeconfig --region ap-south-1 --name sagar-system-monitor-hackathon
```

**Purpose**

Create Kubernetes client configuration for the private EKS cluster using the helper host's IAM identity.

**Important output — exact retained checkpoint**

```text
Added new context arn:aws:eks:ap-south-1:859934688742:cluster/sagar-system-monitor-hackathon to /home/ssm-user/.kube/config
```

**Result:** SUCCESS

## 4.2 Prove private API connectivity and worker health

**Command**

```bash
kubectl get nodes -o wide
```

**Purpose**

Prove both network reachability to the private EKS endpoint and Kubernetes authorization.

**Important output — verified**

```text
ip-10-42-137-89.ap-south-1.compute.internal   Ready   ...   v1.36.2-eks-254016e   10.42.137.89   <none>   ...
ip-10-42-153-66.ap-south-1.compute.internal   Ready   ...   v1.36.2-eks-254016e   10.42.153.66   <none>   ...
```

Both workers had no external IP.

**Result:** SUCCESS

**Meaning**

The private EKS design was working. There was no need to make the Kubernetes API public.

### Earlier Windows kubectl attempt

**Important error**

```text
501 Unsupported method ('GET')
```

**Result:** FAILED ACCESS PATH

**Meaning / fix**

Windows was not a valid network path to the private EKS endpoint. We stopped using Windows `kubectl` and moved Kubernetes administration to the private SSM helper.

---

# 5. Get the hackathon repository onto the helper

## 5.1 Clone the repository

**Command — reconstructed from verified checkpoint**

```bash
git clone https://github.com/sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon.git
```

**Purpose**

Put the GitOps/bootstrap code on the private helper.

**Verified location**

```text
/home/ssm-user/System-Monitor-DORA-SOTA-Hackathon
```

**Result:** SUCCESS

## 5.2 Enter the repo and fast-forward to current main

**Commands**

```bash
cd ~/System-Monitor-DORA-SOTA-Hackathon
git pull --ff-only
```

**Purpose**

Ensure the helper executes exactly the committed public repository state and does not create a divergent local history.

**Result:** SUCCESS

---

# 6. First Argo CD bootstrap attempt

## 6.1 Run the private-cluster bootstrap

**Command**

```bash
bash gitops/scripts/bootstrap-argocd-cloudshell.sh
```

**Purpose**

Automate the private-cluster bootstrap. The script verifies identity, refreshes kubeconfig, checks nodes and EBS CSI, creates namespaces, prepares the Monitor runtime secret, installs pinned Argo CD, creates the AppProject/Application, and waits for `Synced` + `Healthy`.

**Successful steps before the failure — verified**

```text
AWS identity verification: passed
kubeconfig refresh: passed
private Kubernetes API connectivity: passed
worker nodes: Ready
EBS CSI add-on: ACTIVE
argocd namespace: prepared
system-monitor namespace: prepared
```

**Failure — exact important output**

```text
An error occurred (AccessDeniedException) when calling the PutSecretValue operation: Access to KMS is not allowed
```

**Result:** FAILED SAFELY

**Meaning**

The temporary bootstrap role could access Secrets Manager but could not use the customer-managed KMS key protecting the secret.

**Important safety fact**

Argo CD installation had not started when this failure happened, so we did not claim a deployment success.

---

# 7. Diagnose and fix the KMS permission blocker

## 7.1 Retrieve the Terraform platform KMS key

**Command — representative; exact output verified**

```bash
terraform output -raw platform_kms_key_arn
```

**Purpose**

Find the exact KMS CMK that protects hackathon platform secrets so IAM permission can be scoped to one key rather than `*`.

**Important output**

```text
arn:aws:kms:ap-south-1:859934688742:key/2e010c48-d182-4084-80be-1e70db88cb60
```

**Result:** SUCCESS

## 7.2 Add narrowly scoped temporary KMS permissions

The temporary inline policy was extended with only:

```text
kms:GenerateDataKey
kms:Decrypt
```

and only for:

```text
arn:aws:kms:ap-south-1:859934688742:key/2e010c48-d182-4084-80be-1e70db88cb60
```

**Purpose**

Allow Secrets Manager to encrypt/decrypt the runtime secret while maintaining least privilege.

**Result:** SUCCESS

## 7.3 Read back the role policy

**Command — reconstructed from verified checkpoint**

```bash
aws iam get-role-policy --role-name sagar-monitor-hackathon-admin-temp --policy-name sagar-monitor-eks-bootstrap-temp
```

**Purpose**

Verify that the temporary role actually contained the two KMS actions before retrying the bootstrap.

**Result:** SUCCESS

---

# 8. Second Argo CD bootstrap attempt

## 8.1 Retry bootstrap

**Command**

```bash
bash gitops/scripts/bootstrap-argocd-cloudshell.sh
```

**Purpose**

Retry exactly the committed bootstrap after correcting only the missing KMS permission.

**Important successful output / events — verified**

```text
Generated and stored a new Monitor admin password in Secrets Manager
secret/monitor-runtime created
Argo CD v3.5.0 installed
argocd-server rollout succeeded
repo-server rollout succeeded
applicationset-controller rollout succeeded
AppProject created
Application created
operation phase: Succeeded
message: successfully synced (all tasks run)
```

**Argo state after sync**

```text
SYNC STATUS: Synced
HEALTH STATUS: Progressing, later Degraded
```

**Script ending**

```text
Argo CD application did not become Synced/Healthy.
```

**Result:** PARTIAL SUCCESS — GITOPS SYNC WORKED, APPLICATION HEALTH FAILED

**Meaning**

Argo CD itself was working and applying Git correctly. One workload was unhealthy, so the bootstrap correctly refused to claim full success.

---

# 9. Inspect live Kubernetes workload after Argo sync

**Verified workload state at failure**

```text
AI Ops:   2 pods Running 1/1
DORA:     1 pod Running 1/1
UI:       2 pods Running 1/1
Monitor:  0/1 CrashLoopBackOff
```

**Verified persistent storage**

```text
dora-data      Bound   10Gi   gp3-encrypted
monitor-data   Bound   20Gi   gp3-encrypted
```

**Meaning**

Networking, scheduling, EBS CSI provisioning, AI Ops, DORA, and UI were healthy. Diagnosis narrowed to the Monitor container startup path.

---

# 10. Monitor CrashLoopBackOff diagnosis

## 10.1 Read logs from the previous crashed Monitor container

**Command — exact**

```bash
kubectl -n system-monitor logs pod/monitor-7b647c8778-2tb5w --previous --tail=200
```

**Purpose**

A CrashLoopBackOff container may terminate before it can be inspected. `--previous` reads logs from the last terminated instance.

**Important output — exact**

```text
{"error": "server configuration is not valid JSON", "ok": false}
```

**Result:** SUCCESSFUL DIAGNOSTIC COMMAND; APPLICATION ERROR FOUND

## 10.2 Find the source code that raises that error

**Command — exact**

```bash
grep -Rni --exclude-dir=.git --exclude='*.map' "server configuration is not valid JSON" .
```

**Important output — exact**

```text
./commercial/sagar_monitor/server/config.py:77:        raise RuntimeError("server configuration is not valid JSON") from exc
```

**Result:** SUCCESS

**Meaning**

The failure came from the commercial server configuration loader.

## 10.3 Find callers of the configuration loader

**Command — exact**

```bash
grep -Rni --exclude-dir=.git "load_server_config" commercial
```

**Important output — exact**

```text
commercial/sagar_monitor/server/__init__.py:6:from .config import ServerConfig, load_server_config
commercial/sagar_monitor/server/__init__.py:15:    "load_server_config",
commercial/sagar_monitor/server/cli.py:15:from .config import load_server_config
commercial/sagar_monitor/server/cli.py:90:        config = load_server_config(arguments.config)
commercial/sagar_monitor/server/config.py:70:def load_server_config(path: str | Path) -> ServerConfig:
commercial/tests/test_commercial_server_package.py:16:from sagar_monitor.server.config import ServerConfig, load_server_config
commercial/tests/test_commercial_server_package.py:70:        config = load_server_config(config_path)
```

**Result:** SUCCESS

**Meaning**

The CLI was explicitly passing its `--config` argument into the JSON loader.

## 10.4 Check whether Kubernetes overrides container command/arguments

**Command — exact**

```bash
kubectl -n system-monitor get pod monitor-7b647c8778-2tb5w -o jsonpath='{.spec.containers[0].command}{"\n"}{.spec.containers[0].args}{"\n"}'
```

**Important output — exact**

```text

```

(no command or args were printed)

**Result:** SUCCESS

**Meaning**

Kubernetes was not overriding the image startup command. The problem had to be inside the image `ENTRYPOINT`/startup script or its runtime inputs.

## 10.5 Locate Dockerfiles

**Command — exact**

```bash
find . -iname 'Dockerfile*' -o -iname '*dockerfile*'
```

**Important output — exact**

```text
./hackathon/services/ai_ops/Dockerfile
./hackathon/services/dora_collector/Dockerfile
./hackathon/services/monitor/Dockerfile
./hackathon/ui/Dockerfile
```

**Result:** SUCCESS

**Repository inspection result**

The Monitor Dockerfile uses:

```text
ENTRYPOINT ["/app/entrypoint.sh"]
```

and the entrypoint generates:

```text
/data/server.json
```

before launching the commercial server.

---

# 11. Try to read the generated server configuration directly

## 11.1 First attempt with kubectl exec

**Command — exact**

```bash
kubectl -n system-monitor exec pod/monitor-7b647c8778-2tb5w -- cat /data/server.json
```

**Important output — exact**

```text
error: unable to upgrade connection: container not found ("monitor")
```

**Result:** EXPECTED ERROR

**Meaning**

The container was crashing too quickly for an interactive `exec` connection. We did not change the deployment just to inspect it.

---

# 12. Mount the Monitor EBS PVC into a temporary diagnostic pod

## 12.1 Create a temporary read-only inspection pod

**Command — exact**

```bash
NODE=$(kubectl -n system-monitor get pod -l app.kubernetes.io/name=monitor -o jsonpath='{.items[0].spec.nodeName}'); kubectl -n system-monitor run monitor-inspect --image=859934688742.dkr.ecr.ap-south-1.amazonaws.com/sagar-system-monitor/monitor@sha256:45bfcf9e543ee3fbe40e0ca056b2a24becedbc40585019f6d212869d5681414f --restart=Never --overrides="{\"spec\":{\"nodeName\":\"$NODE\",\"securityContext\":{\"runAsNonRoot\":true,\"runAsUser\":10000,\"runAsGroup\":10000},\"containers\":[{\"name\":\"monitor-inspect\",\"image\":\"859934688742.dkr.ecr.ap-south-1.amazonaws.com/sagar-system-monitor/monitor@sha256:45bfcf9e543ee3fbe40e0ca056b2a24becedbc40585019f6d212869d5681414f\",\"command\":[\"/bin/sh\",\"-c\",\"sleep 3600\"],\"volumeMounts\":[{\"name\":\"data\",\"mountPath\":\"/inspect\",\"readOnly\":true}]}],\"volumes\":[{\"name\":\"data\",\"persistentVolumeClaim\":{\"claimName\":\"monitor-data\",\"readOnly\":true}}]}}" --command -- /bin/sh -c 'sleep 3600'
```

**Purpose**

Use the already signed Monitor image as a harmless sleeping container and attach the existing `monitor-data` PVC read-only so the generated files can be inspected without modifying the data.

**Important output — exact**

```text
Warning: would violate PodSecurity "restricted:latest": allowPrivilegeEscalation != false ...
Warning: would violate PodSecurity "restricted:latest": unrestricted capabilities ...
Warning: would violate PodSecurity "restricted:latest": seccompProfile ...
pod/monitor-inspect created
```

**Result:** SUCCESS WITH PODSECURITY WARNINGS

**Meaning**

The namespace currently warns on restricted Pod Security but enforces baseline. The diagnostic pod was created. These warnings are useful evidence for the later policy-hardening phase.

## 12.2 Confirm diagnostic pod is running

**Command — exact**

```bash
kubectl -n system-monitor get pod monitor-inspect -o wide
```

**Important output — exact**

```text
NAME              READY   STATUS    RESTARTS   AGE   IP              NODE
monitor-inspect   1/1     Running   0          67s   10.42.152.102   ip-10-42-153-66.ap-south-1.compute.internal
```

**Result:** SUCCESS

## 12.3 Read the actual generated JSON from EBS

**Command — exact**

```bash
kubectl -n system-monitor exec monitor-inspect -- cat /inspect/server.json
```

**Important output — exact**

```json
{
  "bind_host": "0.0.0.0",
  "port": tcp://172.20.177.2:8443,
  "database_path": "/data/commercial.db",
  "certificate_file": "/data/tls/server.crt",
  "private_key_file": "/data/tls/server.key",
  "backup_directory": "/data/backups",
  "max_body_bytes": 2097152,
  "max_header_bytes": 32768,
  "socket_timeout_seconds": 30,
  "allow_loopback_http": false,
  "server_label": "Sagar Monitor DORA SOTA Hackathon"
}
```

**Result:** SUCCESS — ROOT CAUSE FOUND

**Root cause**

Kubernetes service-link environment injection created a variable named `MONITOR_PORT` for the Kubernetes Service named `monitor`. Its value was:

```text
tcp://172.20.177.2:8443
```

The Monitor image also used `MONITOR_PORT` as its application listen-port variable. The shell entrypoint inserted that unquoted service URL into JSON:

```json
"port": tcp://172.20.177.2:8443
```

which is invalid JSON. This exactly explains the earlier error:

```text
server configuration is not valid JSON
```

---

# 13. Remove the temporary diagnostic pod

**Command — exact**

```bash
kubectl -n system-monitor delete pod monitor-inspect
```

**Important output — exact**

```text
pod "monitor-inspect" deleted from system-monitor namespace
```

**Result:** SUCCESS

**Purpose / meaning**

Release the EBS volume from the temporary reader before Argo starts the corrected Monitor workload.

---

# 14. Permanent code fix — Hackathon 3.68

**Git commit**

```text
Hackathon 3.68 - Fix Kubernetes monitor port collision
fd0ab5cc3d3c33bfd39117b531fa06d08dc23a03
```

**Fix**

The entrypoint now resolves the listen port through a collision-safe path:

```sh
RAW_PORT="${MONITOR_LISTEN_PORT:-${MONITOR_PORT:-8443}}"
case "$RAW_PORT" in
  ''|*[!0-9]*) PORT=8443 ;;
  *) PORT="$RAW_PORT" ;;
esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo "Monitor listen port must be between 1 and 65535." >&2
  exit 2
fi
```

**Purpose**

Prefer a dedicated `MONITOR_LISTEN_PORT`. If Kubernetes injects a non-numeric `MONITOR_PORT=tcp://...`, reject that value and safely use 8443 instead of generating malformed JSON.

**Result:** COMMITTED

---

# 15. Check CI / supply-chain status for Hackathon 3.68

## 15.1 Python GitHub API attempt

**Command — exact**

```bash
python -c 'import json,urllib.request; d=json.load(urllib.request.urlopen("https://api.github.com/repos/sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon/actions/runs?head_sha=fd0ab5cc3d3c33bfd39117b531fa06d08dc23a03&per_page=20")); print("\n".join(f"{r['id']} | {r['name']} | {r['status']} | {r['conclusion']}" for r in d["workflow_runs"]))'
```

**Important output — exact**

```text
sh: python: command not found
```

**Result:** EXPECTED TOOLING ERROR

**Meaning / fix**

The minimal Amazon Linux helper did not have a `python` executable. We avoided installing unnecessary packages and switched to `curl`.

## 15.2 Query GitHub Actions using curl

**Command — exact**

```bash
curl -fsSL "https://api.github.com/repos/sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon/actions/runs?head_sha=fd0ab5cc3d3c33bfd39117b531fa06d08dc23a03&per_page=20" | grep -E '"id":|"name":|"status":|"conclusion":' | head -80
```

**Important output — exact relevant lines**

```text
"id": 31483388324,
"name": "Hackathon Phase 1 CI",
"status": "completed",
"conclusion": "success",

"id": 31483388301,
"name": "Hackathon Container Supply Chain",
"status": "completed",
"conclusion": "success",
```

**Result:** SUCCESS

**Meaning**

The 3.68 change passed Phase 1 CI and the complete container supply-chain workflow.

The supply-chain workflow includes build, Trivy HIGH/CRITICAL gate, CycloneDX SBOM, ECR publish, GitHub OIDC, Cosign keyless signing, attestation, and verification.

**Corrected signed Monitor image digest**

```text
859934688742.dkr.ecr.ap-south-1.amazonaws.com/sagar-system-monitor/monitor@sha256:4bd4abf6f7fcfe7bc7c325f4b00b1562a4714961fb252a1f97b496ea276dfb24
```

---

# 16. GitOps digest update — Hackathon 3.69

**Git commit**

```text
Hackathon 3.69 - Update Monitor signed image digest
3d6c8241c5d2dad7d5f4227ba10fc9ef33814e60
```

**Purpose**

Keep Kubernetes deployment immutable and supply-chain verified by deploying the exact signed digest rather than a mutable image tag.

**Changed only**

```text
Monitor image digest
```

**Unchanged**

```text
AI Ops image
DORA image
UI image
PVCs
Services
production System Monitor
```

---

# 17. Confirm Argo CD sees Hackathon 3.69

**Command — exact**

```bash
kubectl -n argocd get application system-monitor -o wide
```

**Important output — exact**

```text
NAME             SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
system-monitor   Synced        Progressing     3d6c8241c5d2dad7d5f4227ba10fc9ef33814e60   system-monitor
```

**Result:** IN PROGRESS

**Meaning**

Argo CD has already synced the exact `Hackathon 3.69` Git revision. The application is still `Progressing`, so full GitOps deployment success is **not yet claimed**. The next diagnostic step is to inspect the live pods and confirm whether the new Monitor pod becomes `1/1 Running`.

---

# 18. Key lessons / why these commands matter

1. `aws ssm start-session` — secure administrative path to a private VPC host without SSH/public IP.
2. `aws eks update-kubeconfig` — binds kubectl to EKS through AWS IAM authentication.
3. `kubectl get nodes -o wide` — proves both private network connectivity and Kubernetes authorization.
4. `bash gitops/scripts/bootstrap-argocd-cloudshell.sh` — deterministic bootstrap and health gate; it refuses to report success when workloads are unhealthy.
5. `kubectl logs --previous` — essential for CrashLoopBackOff diagnostics.
6. `grep -Rni` — traces a runtime error back to the exact code path without guessing.
7. Kubernetes JSONPath command/args check — determines whether startup is controlled by Kubernetes or the image itself.
8. Temporary read-only PVC inspection — lets us inspect persistent runtime state even when the real container cannot stay alive.
9. GitHub Actions query — independently confirms CI and supply-chain results.
10. Digest pinning — makes the deployed artifact immutable and auditable.
11. Recording failed commands is important — failures show the troubleshooting path, security constraints, and engineering decisions; they are useful hackathon evidence rather than something to hide.

---

# 19. Current exact state

As of the latest captured command on 2026-08-11:

```text
Argo CD Application: system-monitor
Sync:   Synced
Health: Progressing
Revision: 3d6c8241c5d2dad7d5f4227ba10fc9ef33814e60
```

The next live check must verify pod state, especially the corrected Monitor pod. Full `Synced + Healthy` evidence is still pending.

---

# 20. Documentation rule for all remaining hackathon work

For every meaningful command from this point forward, append:

```text
Date/time
Command
Purpose
Important output
Result
Meaning
Next action
```

Include successful commands and useful failures. Never record secret values. Never mark a deployment/test as passed unless the terminal or CI evidence proves it.
