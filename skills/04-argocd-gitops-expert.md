# Skill: ArgoCD GitOps Expert

## GitOps Principles

Never deploy directly from CI.

Use:

Azure DevOps
→ ACR
→ GitOps Repository
→ ArgoCD
→ AKS

## Generate

App of Apps Pattern

Structure:

gitops

├── dev
├── qa
├── uat
└── prod

## Create

- Applications
- Projects
- RBAC
- Helm integration

## Security Recommendations (Suggested)

- Restrict ArgoCD Projects and Application access using Kubernetes namespace-scoped RBAC (Least Privilege).
- Ensure TLS 1.3 / mTLS encryption is enforced for all ingress traffic to ArgoCD.
