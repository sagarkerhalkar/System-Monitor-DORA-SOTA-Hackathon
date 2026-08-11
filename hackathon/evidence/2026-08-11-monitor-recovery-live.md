# 2026-08-11 — Monitor Recovery Live Evidence

This file continues the permanent command/evidence trail in `hackathon/COMMAND_AND_EVIDENCE_LOG.md` for the live Monitor recovery after Hackathon 3.68/3.69.

Security rule: never record passwords, secret values, tokens, credentials, private keys, or decrypted secret contents.

## Checkpoint 1 — Verify pods after Argo synced the corrected Monitor digest

**Local time:** approximately 2026-08-11 16:44 IST

### Command

```bash
kubectl -n system-monitor get pods -o wide
```

### Purpose

Verify the live pod state after Argo CD synchronized GitOps revision `3d6c8241c5d2dad7d5f4227ba10fc9ef33814e60` (`Hackathon 3.69`), which updated the Monitor deployment to the corrected signed image produced from `Hackathon 3.68`.

### Exact output

```text
NAME                       READY   STATUS             RESTARTS      AGE   IP              NODE                                          NOMINATED NODE   READINESS GATES
ai-ops-bd64d9d74-nbfgz     1/1     Running            0             71m   10.42.129.194   ip-10-42-137-89.ap-south-1.compute.internal   <none>           <none>
ai-ops-bd64d9d74-wtm4z     1/1     Running            0             71m   10.42.158.250   ip-10-42-153-66.ap-south-1.compute.internal   <none>           <none>
dora-776b7b86d8-5frql      1/1     Running            0             71m   10.42.131.176   ip-10-42-137-89.ap-south-1.compute.internal   <none>           <none>
monitor-7f8ddb959b-92ncc   0/1     CrashLoopBackOff   9 (25s ago)   21m   10.42.157.192   ip-10-42-153-66.ap-south-1.compute.internal   <none>           <none>
ui-54fc5dfd6c-f94rf        1/1     Running            0             71m   10.42.131.242   ip-10-42-137-89.ap-south-1.compute.internal   <none>           <none>
ui-54fc5dfd6c-lh4l5        1/1     Running            0             71m   10.42.148.222   ip-10-42-153-66.ap-south-1.compute.internal   <none>           <none>
```

### Result

`FAILED APPLICATION HEALTH / SUCCESSFUL DIAGNOSTIC COMMAND`

### Meaning

- The new Monitor ReplicaSet/pod is present (`monitor-7f8ddb959b-92ncc`) but is still crashing.
- The Monitor has restarted 9 times, so this is a persistent startup/runtime failure rather than a short scheduling delay.
- Both AI Ops pods are healthy.
- DORA is healthy.
- Both UI pods are healthy.
- The failure remains isolated to Monitor.
- Argo CD must **not** be declared fully healthy yet.
- The earlier port-collision root cause was fixed in source and a new signed digest was synced, but this output proves there is at least one additional Monitor startup/runtime blocker or the effective runtime behavior must be re-verified.

### Exact next action

Read the previous terminated container logs for the new Monitor pod:

```bash
kubectl -n system-monitor logs pod/monitor-7f8ddb959b-92ncc --previous --tail=200
```

---

## Checkpoint 2 — Read the new Monitor crash reason

**Local time:** approximately 2026-08-11 16:50 IST

### Command

```bash
kubectl -n system-monitor logs pod/monitor-7f8ddb959b-92ncc --previous --tail=200
```

### Exact output

```text
{"error": "password must contain at least three character classes", "ok": false}
```

### Result

`SUCCESSFUL DIAGNOSTIC COMMAND / SECOND STARTUP BLOCKER FOUND`

### Meaning

- Hackathon 3.68 fixed the malformed JSON port problem because that error is no longer present.
- Monitor now reaches the first-admin bootstrap step.
- The runtime password currently stored for the first bootstrap does not satisfy the commercial password policy.
- The bootstrap script generated the original secret with `openssl rand -hex 24`; hexadecimal output contains only lowercase hexadecimal letters and digits, which supplies only two character classes.
- No password or secret value was printed or recorded.

### Next safety question

Before rotating the secret, verify whether the failed bootstrap created `/data/commercial.db`. If a database already existed, password rotation alone might not be sufficient because the Monitor entrypoint follows a different path for an existing database.

---

## Checkpoint 3 — Identify the Monitor node

### Command

```bash
kubectl -n system-monitor get pod monitor-7f8ddb959b-92ncc -o jsonpath='{.spec.nodeName}{"\n"}'
```

### Exact output

```text
ip-10-42-153-66.ap-south-1.compute.internal
```

### Result

`SUCCESS`

### Purpose / meaning

Identify the node currently holding the Monitor pod so a short-lived read-only PVC inspection pod can be scheduled on the same node.

---

## Checkpoint 4 — Read-only database existence check

### Command

```bash
kubectl -n system-monitor run monitor-db-check --rm -i --restart=Never --image=859934688742.dkr.ecr.ap-south-1.amazonaws.com/sagar-system-monitor/monitor@sha256:4bd4abf6f7fcfe7bc7c325f4b00b1562a4714961fb252a1f97b496ea276dfb24 --overrides='{"spec":{"nodeName":"ip-10-42-153-66.ap-south-1.compute.internal","securityContext":{"runAsNonRoot":true,"runAsUser":10000,"runAsGroup":10000,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"monitor-db-check","image":"859934688742.dkr.ecr.ap-south-1.amazonaws.com/sagar-system-monitor/monitor@sha256:4bd4abf6f7fcfe7bc7c325f4b00b1562a4714961fb252a1f97b496ea276dfb24","command":["/bin/sh","-c","if [ -e /inspect/commercial.db ]; then stat -c \"commercial.db size=%s bytes\" /inspect/commercial.db; else echo \"commercial.db missing\"; fi"],"securityContext":{"allowPrivilegeEscalation":false,"readOnlyRootFilesystem":true,"capabilities":{"drop":["ALL"]}},"volumeMounts":[{"name":"data","mountPath":"/inspect","readOnly":true}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"monitor-data","readOnly":true}}]}}'
```

### Exact output

```text
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
warning: couldn't attach to pod/monitor-db-check, falling back to streaming logs: unable to upgrade connection: container monitor-db-check not found in pod monitor-db-check_system-monitor
commercial.db missing
pod "monitor-db-check" deleted from system-monitor namespace
```

### Result

`SUCCESS WITH BENIGN ATTACH WARNING`

### Meaning

- `commercial.db missing` is the important result.
- The failed password bootstrap did not leave a partially initialized database behind.
- No database cleanup or destructive recovery is required.
- The temporary inspection pod deleted itself successfully.
- The attach warning occurred because the short-lived container completed before interactive attach; Kubernetes then streamed the logs, which contained the required result.
- We can safely fix/rotate the bootstrap password path and let the first successful Monitor start create the database normally.

### Exact next action

Locate the exact commercial password-policy implementation and confirm all requirements before changing the password generator and existing stored secret.
