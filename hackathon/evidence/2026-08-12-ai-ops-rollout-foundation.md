# 2026-08-12 - AI Ops Argo Rollout Foundation

## Scope

Hackathon 3.82 converts only AI Ops from a Kubernetes Deployment to an Argo Rollout. Monitor, UI, DORA, database/PVCs, production `workingcode`, EKS endpoint security, and permanent EBS CSI infrastructure remain unchanged.

## Starting repository state

- `bd8a11877948528aa1d528beaee793e27fb60abf` - `Hackathon 3.81 - Add chronological evidence continuation`
- helper `HEAD`, `origin/main`, and GitHub `main` synchronized
- helper working tree clean
- safety stash retained: `stash@{0}: On main: pre-sync local Hackathon 3.81 evidence`

## 3.81 follow-up CI

Hackathon Phase 1 CI run `31604402264` completed successfully for the evidence-only follow-up commit.

**Result:** PASS

## Helper kubectl PATH failure

**Command:** node-capacity query using `kubectl`.

**Observed:** `sh: kubectl: command not found`

**Result:** FAIL

**Root cause:** the new SSM shell did not include `$HOME/bin`, where kubectl is installed.

**Fix:** `export PATH="$HOME/bin:$PATH"`

**Verification:** `/home/ssm-user/bin/kubectl`; client `v1.35.3-eks-bbe087e`; Kustomize `v5.7.1`.

**Result after fix:** PASS

## Metrics-server limitation

**Command:** `kubectl top nodes`

**Observed:** `metrics-server not available`

**Result:** EXPECTED TOOLING LIMITATION

Live utilization could not be read through Metrics API, so capacity was evaluated from Kubernetes allocatable values and scheduler resource requests.

## Node capacity evidence

Both worker nodes reported:

- allocatable CPU: `1930m` each
- allocatable memory: `7249524Ki` each
- allocatable pod slots: `35` each

Current requested resources:

### Worker `ip-10-42-137-89.ap-south-1.compute.internal`

- CPU requests: `390m` (20%)
- memory requests: `560Mi` (7%)
- pod count: `13`

### Worker `ip-10-42-153-66.ap-south-1.compute.internal`

- CPU requests: `640m` (33%)
- memory requests: `860Mi` (12%)
- pod count: `13`

Each node therefore had 22 free pod slots at precheck time, 44 free slots cluster-wide.

## AI Ops starting state

The existing `ai-ops` Deployment was healthy before conversion:

- replicas: `2`
- ready: `2/2`
- available: `2`
- image digest pinned
- two pods `1/1 Running`
- zero restarts
- one AI Ops pod scheduled on each worker

**Result:** PASS

## Capacity calculation for 20 replicas

AI Ops requests per pod:

- CPU `50m`
- memory `64Mi`

Existing 2 replicas request `100m` CPU and `128Mi` memory.

A 20-replica target requests `1000m` CPU and `1280Mi` memory total, an increase of `900m` CPU and `1152Mi` memory over the starting AI Ops Deployment.

The cluster had adequate requested-resource and pod-slot headroom for this target. With canary `maxSurge: 25%`, the Rollout may temporarily create up to 25 AI Ops pods. The precheck still leaves sufficient aggregate pod slots and resource-request capacity.

**Result:** PASS FOR FOUNDATION DEPLOYMENT

## Canary design decision

The current basic ClusterIP Service remains unchanged and continues selecting `app.kubernetes.io/name: ai-ops`.

No service mesh, ALB traffic router, public EKS endpoint, or new ingress dependency is introduced in this stage.

Argo Rollouts basic canary without traffic management approximates `setWeight` using stable/canary ReplicaSet pod counts. With `spec.replicas: 20`, the required stages map exactly to whole pod counts:

- 10% = 2/20 canary pods
- 25% = 5/20 canary pods
- 50% = 10/20 canary pods
- 100% = 20/20 canary pods

The Rollout strategy therefore uses:

- `maxSurge: 25%`
- `maxUnavailable: 0`
- `setWeight: 10`, pause 60s
- `setWeight: 25`, pause 60s
- `setWeight: 50`, pause 60s
- `setWeight: 100`

## Safe Deployment-to-Rollout migration

The Argo CD Application already has `PruneLast=true` together with automated sync, prune, and self-heal.

The GitOps base replaces the AI Ops `apps/v1 Deployment` with an `argoproj.io/v1alpha1 Rollout` of the same workload name and pod labels. `PruneLast=true` is retained and is now enforced by GitOps CI.

The first 3.82 commit establishes a healthy Rollout baseline. It intentionally uses pod-template annotation:

`hackathon.sagarkerhalkar.com/canary-revision: baseline`

A later 3.82 pod-template-only revision will change that annotation to create a new ReplicaSet and exercise the actual 10% -> 25% -> 50% -> 100% progression. This avoids falsely claiming a canary on the first-ever Rollout revision, where there is no previous Rollout-owned stable ReplicaSet.

## GitOps CI guardrail

The GitOps workflow is strengthened to require:

- AI Ops is an Argo Rollout
- exactly 20 desired replicas for this demonstration
- `maxSurge: 25%`
- `maxUnavailable: 0`
- weights 10, 25, 50, 100
- the canary revision annotation
- absence of the legacy AI Ops Deployment
- existing `PruneLast=true` migration safety
- four digest-pinned application images
- no `:latest`
- existing storage and security contracts

## Security

No secret value, password, token, session credential, cookie, or private key is recorded.

The EKS API remains private-only. No security control was weakened for the progressive-delivery demo.

## Completion gate

This foundation commit is not sufficient to close Hackathon 3.82.

Required next evidence:

1. GitHub Actions PASS/FAIL for the foundation commit.
2. Argo CD revision synchronized.
3. AI Ops Rollout healthy at 20 replicas.
4. Legacy AI Ops Deployment pruned safely.
5. Monitor/UI/DORA remain healthy.
6. A second pod-template revision triggers the canary.
7. Live evidence proves 10% -> 25% -> 50% -> 100% progression.
8. All failures/fixes and final verification are recorded in GitHub.
