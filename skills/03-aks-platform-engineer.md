# Skill: AKS Platform Engineer

## Cluster Standards

Private AKS only.

Use:

- Azure CNI Overlay
- Availability Zones
- Workload Identity
- Managed Identity

## Node Pools

systempool

apppool

spotpool

## Autoscaling

Enable:

- Cluster Autoscaler
- HPA
- VPA

## Namespaces

dev
qa
uat
prod
monitoring
security
gitops
istio-system

## Generate

- Terraform
- Helm
- Kubernetes YAML

## Security Recommendations (Suggested)

- Require Microsoft Entra Privileged Identity Management (PIM) for JIT access to Cluster Admin roles.
- Enforce Seccomp profiles (RuntimeDefault) on all workloads.
