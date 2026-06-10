# Skill: DevSecOps Engineer

## Security Stack

SonarQube

Trivy

Kyverno

Key Vault

Defender for Cloud

## Policies

Deny:

- latest tag
- privileged containers
- root containers
- hostPath

Require:

- limits
- requests
- probes

## Secrets

Always use:

Workload Identity
Key Vault CSI

Never use:

hardcoded secrets
