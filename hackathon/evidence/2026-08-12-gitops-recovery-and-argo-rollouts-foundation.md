# 2026-08-12 - GitOps Recovery and Argo Rollouts Foundation

## Evidence rule

All meaningful commands, failures, fixes, PASS results, security decisions, and explanations in this milestone are retained as engineering evidence. Secret values are intentionally excluded.

## 1. GitOps Monitor recovery

### Bootstrap prerequisite failure

**Command**

```bash
bash gitops/scripts/bootstrap-argocd-cloudshell.sh
```

**Result:** FAIL

**Important output**

```text
Required command not found: kubectl
```

**Root cause**

The kubectl binary already existed at `/home/ssm-user/bin/kubectl`, but a new SSM shell did not include `$HOME/bin` in `PATH`.

**Fix**

```bash
export PATH="$HOME/bin:$PATH"
```

**Verification**

```bash
kubectl get nodes
```

Both EKS workers reported `Ready` on Kubernetes `v1.36.2-eks-254016e`.

**Result after fix:** PASS

### GitOps bootstrap after PATH recovery

**Command**

```bash
bash gitops/scripts/bootstrap-argocd-cloudshell.sh
```

**Result:** PASS

**Important output**

```text
sync=Synced health=Healthy
GitOps bootstrap passed
```

Argo CD revision:

```text
bbb9af0301a329d699e92a499409e7a061327240
```

Commit:

```text
Hackathon 3.80 - Align bootstrap password policy
```

All application pods reported Running, including Monitor `1/1` with zero restarts. Both encrypted PVCs were Bound.

### Monitor application verification

**Command**

```bash
kubectl -n system-monitor logs deployment/monitor --tail=100
```

**Result:** PASS

Verified runtime state:

- database path `/data/commercial.db`
- database `quick_check: ok`
- active admins `1`
- migrations expected `7`, applied `7`
- no pending, mismatched, or unexpected migrations
- TLS enabled
- certificate present
- private key present

This proved application health beyond the Kubernetes Running state.

## 2. Argo Rollouts starting state

Prechecks confirmed the following did not yet exist:

- namespace `argo-rollouts`
- CRD `rollouts.argoproj.io`
- CRD `analysistemplates.argoproj.io`

**Result:** EXPECTED ABSENT

This provided a clean installation baseline.

## 3. Argo Rollouts v1.9.1 installation

Downloaded release artifact:

```text
https://github.com/argoproj/argo-rollouts/releases/download/v1.9.1/install.yaml
```

Pinned SHA-256:

```text
78c82343803c2bbc13a36049e269a532dd67f25b7e2cb3603c99e31d8d8a40b5
```

Checksum verification:

```text
argo-rollouts-v1.9.1-install.yaml: OK
```

**Result:** PASS

The namespace, CRDs, service account, cluster roles, cluster role binding, config map, notification secret, metrics service, and controller deployment were created.

Controller rollout:

```text
deployment "argo-rollouts" successfully rolled out
```

Required CRDs verified:

```text
rollouts.argoproj.io
analysistemplates.argoproj.io
analysisruns.argoproj.io
experiments.argoproj.io
```

Controller pod:

```text
READY 1/1
STATUS Running
RESTARTS 0
```

## 4. Windows kubectl access failure

After leaving the SSM helper, kubectl was accidentally invoked from Windows PowerShell.

**Result:** FAIL

**Important output**

```text
501 Unsupported method ('GET')
```

PowerShell also treated `-o` as a separate command because Linux backslash line-continuation syntax was pasted into PowerShell.

**Root cause**

The EKS API is private-only. The Windows host did not have the required private VPC path to the Kubernetes endpoint, and Linux continuation syntax is not PowerShell syntax.

**Security decision**

The EKS public API was not enabled for convenience.

**Fix**

Reconnect to the private Amazon Linux helper through AWS Systems Manager, restore `$HOME/bin` in `PATH`, and perform Kubernetes administration from the private helper.

**Verification**

Both EKS workers again reported `Ready`.

**Result after fix:** PASS

## 5. Controller version verification

**Command**

```bash
kubectl -n argo-rollouts get deployment argo-rollouts -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

**Result:** PASS

Verified image:

```text
quay.io/argoproj/argo-rollouts:v1.9.1
```

## 6. Permanent repository bootstrap

Implementation:

```text
gitops/scripts/bootstrap-argo-rollouts.sh
```

The script:

- pins Argo Rollouts `v1.9.1`
- pins the release manifest SHA-256
- checks required local commands
- verifies Kubernetes API connectivity
- downloads the exact release manifest
- verifies artifact integrity
- creates/reconciles the namespace
- applies the controller and CRDs
- waits for controller rollout
- verifies required CRDs
- verifies the controller image version

### Syntax validation

**Command**

```bash
bash -n gitops/scripts/bootstrap-argo-rollouts.sh
```

**Result:** PASS

No syntax errors were printed.

### Idempotency validation

**Command**

```bash
bash gitops/scripts/bootstrap-argo-rollouts.sh
```

**Result:** PASS

Existing resources reconciled primarily as `unchanged`; the deployment reconciled successfully; all required CRDs were verified.

Final output:

```text
Argo Rollouts bootstrap passed
Controller image: quay.io/argoproj/argo-rollouts:v1.9.1
```

Controller remained `1/1 Running` with zero restarts.

## 7. GitHub Actions guardrail

Implementation:

```text
.github/workflows/hackathon-rollouts-ci.yml
```

The workflow validates:

- Bash syntax
- pinned Rollouts version `v1.9.1`
- pinned release manifest SHA-256
- required CRD contracts
- rejection of floating `:latest`

The post-push CI result must be captured separately before Hackathon 3.81 is considered fully closed.

## 8. Evidence-file working-directory failure

An attempt to create:

```text
hackathon/EVIDENCE_POLICY.md
```

returned:

```text
No such file or directory
```

**Result:** FAIL

**Root cause**

The active shell was not inside `/home/ssm-user/System-Monitor-DORA-SOTA-Hackathon`.

**Fix**

```bash
cd ~/System-Monitor-DORA-SOTA-Hackathon
```

**Verification**

`pwd` returned the expected repository path and `ls hackathon` displayed the project evidence directory.

**Result after fix:** PASS

## 9. Compulsory GitHub evidence policy

Implementation:

```text
hackathon/EVIDENCE_POLICY.md
```

The policy makes GitHub evidence compulsory for all remaining meaningful engineering actions, including command/code, expected result, actual result, PASS/FAIL status, error, root cause, fix, verification, security decision, and next action.

Failures must remain in the project history after they are fixed.

Passwords, secret values, access tokens, session credentials, cookies, and private keys must never be committed.

## 10. Staged pre-commit validation

Observed local validation results before the first push attempt:

```text
git diff --cached --check
```

**Result:** PASS - no output/errors.

```text
bash -n gitops/scripts/bootstrap-argo-rollouts.sh
```

**Result:** PASS - no output/errors.

The staged local change set contained six intended files and 360 insertions at that checkpoint.

No unverified secret-scan PASS is claimed here because its terminal output was not captured in the evidence supplied for this checkpoint.

## 11. HTTPS Git push authentication failure

A local `git push origin main` attempt prompted for GitHub username and password.

**Result:** FAIL

**Important output**

```text
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/sagarkerhalkar/System-Monitor-DORA-SOTA-Hackathon.git/'
```

**Root cause**

GitHub does not support account-password authentication for HTTPS Git operations. Entering the GitHub account password cannot authenticate a push.

**Security decision**

No password, personal access token, or secret credential is committed or pasted into repository evidence.

**Corrective action**

Use the already connected GitHub application, which has push permission on this repository, to publish the milestone without weakening authentication or exposing a token.

## Safety state

- production `workingcode` was not modified
- EKS API remains private-only
- no secret value is recorded in this evidence
- Monitor, UI, DORA, and AI Ops application workloads were not converted during the Rollouts-controller foundation stage
- permanent EBS CSI infrastructure remains untouched

## Next action

Publish Hackathon 3.81 through the connected GitHub app, verify the resulting commit and GitHub Actions result, record CI PASS or FAIL, and only then begin Hackathon 3.82 AI Ops canary conversion.
