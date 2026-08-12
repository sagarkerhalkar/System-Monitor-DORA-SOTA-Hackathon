# 2026-08-12 — Hackathon 3.81 chronological evidence continuation

This dated continuation preserves the 3.81 command/failure/pass sequence that was not appended to `hackathon/COMMAND_AND_EVIDENCE_LOG.md` in the first published 3.81 commit. It complements `hackathon/evidence/2026-08-12-gitops-recovery-and-argo-rollouts-foundation.md` and GitHub issue #7.

## 1. GitOps recovery baseline — PASS

- Argo CD application `system-monitor` reached `Synced` + `Healthy` at Hackathon 3.80 revision `bbb9af0301a329d699e92a499409e7a061327240`.
- Monitor reached `1/1 Running`.
- Monitor database quick check returned `ok`.
- Migrations: expected 7, applied 7, no pending/mismatched/unexpected migrations.
- TLS enabled; certificate and private key present.
- `monitor-data` and `dora-data` PVCs Bound.

## 2. Fresh SSM session kubectl PATH — FAIL then PASS

**FAIL:** `kubectl: command not found` in a fresh helper shell.

**Root cause:** kubectl is installed at `/home/ssm-user/bin/kubectl`, while `$HOME/bin` was not present in the fresh shell PATH.

**Fix:**

```bash
export PATH="$HOME/bin:$PATH"
```

**PASS:** both EKS worker nodes returned `Ready`.

## 3. Argo Rollouts precheck — PASS

Before installation, the `argo-rollouts` namespace and Rollout/AnalysisTemplate CRDs were absent, providing a clean baseline.

## 4. Argo Rollouts release integrity — PASS

- Version: `v1.9.1`
- Release manifest SHA-256: `78c82343803c2bbc13a36049e269a532dd67f25b7e2cb3603c99e31d8d8a40b5`
- SHA verification: PASS.

## 5. Argo Rollouts installation — PASS

- Controller installed successfully.
- Controller image verified as `quay.io/argoproj/argo-rollouts:v1.9.1`.
- Controller pod `1/1 Running`, zero restarts.
- Required CRDs verified:
  - `rollouts.argoproj.io`
  - `analysistemplates.argoproj.io`
  - `analysisruns.argoproj.io`
  - `experiments.argoproj.io`

## 6. Windows kubectl against private EKS — FAIL then recovered

**FAIL:** Windows kubectl returned HTTP `501 Unsupported method ('GET')`; Linux backslash continuation also caused PowerShell to treat `-o` as a separate command.

**Root cause:** private-only EKS API had no valid direct Windows network path, and Bash continuation syntax is not PowerShell syntax.

**Security decision:** the EKS public API was not enabled for convenience.

**Recovery:** return to the private SSM helper, restore `$HOME/bin` PATH, verify both nodes Ready.

## 7. Permanent Rollouts bootstrap — PASS

Created `gitops/scripts/bootstrap-argo-rollouts.sh` with:

- pinned Rollouts `v1.9.1`
- pinned manifest SHA-256
- Kubernetes API connectivity check
- release checksum verification
- idempotent namespace/apply flow
- controller rollout wait
- required CRD verification
- controller image version verification

`bash -n` validation passed.

Idempotent rerun passed; existing resources reconciled primarily as `unchanged` and the controller remained healthy.

## 8. CI guardrail — PASS

Created `.github/workflows/hackathon-rollouts-ci.yml` to enforce:

- Bash syntax
- Rollouts version pin
- manifest checksum pin
- required CRD contracts
- no floating `:latest` tag

GitHub Actions results for 3.81 commit `fb0057fb8ba8a140cf2b0831bde452956ccfc3ad`:

- Hackathon Argo Rollouts CI — PASS — run `31602046957`
- Hackathon GitOps CI — PASS — run `31602046862`
- Hackathon Phase 1 CI — PASS — run `31602046935`

## 9. Evidence-file creation outside repository — FAIL then PASS

**FAIL:** creating `hackathon/EVIDENCE_POLICY.md` returned `No such file or directory`.

**Root cause:** active shell was not in `/home/ssm-user/System-Monitor-DORA-SOTA-Hackathon`.

**Fix:** `cd ~/System-Monitor-DORA-SOTA-Hackathon`.

**PASS:** `pwd` and `ls hackathon` verified the repository directory before recreating the evidence file.

## 10. Local commit author identity — FAIL

**Command:**

```bash
git commit -m "Hackathon 3.81 - Add Argo Rollouts foundation"
```

**Important output:** `Author identity unknown` and `fatal: empty ident name`.

**Root cause:** the temporary SSM helper did not have Git `user.name` / `user.email` configured.

**Impact:** no commit was created and no repository history changed.

**Recovery decision:** do not add unnecessary personal credentials or identity configuration to the temporary helper solely to unblock publishing.

## 11. HTTPS Git push with account password — FAIL

**Important output:** `Password authentication is not supported for Git operations`.

**Root cause:** GitHub HTTPS Git operations do not accept an account password.

**Security decision:** no password, PAT, token, or private key was committed or recorded.

**Recovery:** publish 3.81 through the connected GitHub app with repository push permission.

## 12. Published 3.81 — PASS

Published commit:

```text
fb0057fb8ba8a140cf2b0831bde452956ccfc3ad
Hackathon 3.81 - Add Argo Rollouts foundation
```

All three CI workflows completed successfully.

## 13. Helper synchronization — PASS

Local 3.81 staged work was preserved first:

```text
stash@{0}: On main: pre-sync local Hackathon 3.81 evidence
```

Then password-free fetch/fast-forward synchronized the helper to remote 3.81:

```text
fb0057f (HEAD -> main, origin/main, origin/HEAD) Hackathon 3.81 - Add Argo Rollouts foundation
```

Working tree was clean after synchronization. The safety stash was intentionally retained.

## Security

No secret value, password, access token, session credential, cookie, or private key is stored in this file.
