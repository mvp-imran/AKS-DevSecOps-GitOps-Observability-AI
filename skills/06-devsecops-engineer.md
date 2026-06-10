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

## Security Recommendations (Suggested)

- Enforce automated secret rotation in Azure Key Vault.
- Restrict egress rules in Kyverno to whitelisted domains only.
