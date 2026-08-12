# Hackathon Evidence Policy

This policy is compulsory for all remaining System Monitor DORA/SOTA hackathon work.

## Mandatory GitHub evidence

Every meaningful engineering action must be stored in GitHub, including:

- command or code used
- purpose and expected result
- actual output or verified result
- PASS, FAIL, EXPECTED ERROR, or IN PROGRESS status
- error message when something fails
- root cause and technical explanation
- fix or corrective action
- verification after the fix
- security decision or safety constraint
- next action

Failures must remain in the engineering history after they are fixed. They must not be deleted merely to make the project appear successful.

## Evidence locations

- hackathon/COMMAND_AND_EVIDENCE_LOG.md for chronological command history
- hackathon/evidence/ for detailed milestone and incident evidence
- repository scripts, manifests, workflows, and tests for reproducible implementation

## Security exception

Never commit passwords, secret values, access tokens, session credentials, cookies, private keys, or other sensitive credentials.

Secret names, secret locations, redacted identifiers, PASS/FAIL results, and technical explanations may be recorded when they do not expose secret values.

## Completion rule

A hackathon stage is not complete until its implementation, failures, fixes, validation results, and explanation are stored in GitHub.
