# Skill: Azure DevOps Expert

## CI Standards

Generate pipelines:

Build
Unit Test
SonarQube
Trivy
Docker Build
Push ACR
Update GitOps

## Reusable Templates

Create:

templates/

build.yml

security.yml

docker.yml

gitops.yml

## Branch Policies

Require:

- PR Approval
- Security Checks
- Build Validation

## Security Recommendations (Suggested)

- Enforce Azure Workload Identity (OIDC Federation) for pipeline service connections, avoiding long-lived client secrets.
- Mandate automated static analysis (SonarQube) and container vulnerability scans (Trivy) as release gate blockers.
