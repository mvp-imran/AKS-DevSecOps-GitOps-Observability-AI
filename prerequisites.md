# 📋 Deployment Prerequisites Audit Checklist
### Master Checklist for Enterprise AKS Platform Deployment

This document combines the requirements from **[deployment _plan.md](file:///c:/RnD/AKS-DevSecOps-GitOps-Observability-AI/deployment%20_plan.md)** and **[deployment_guide.md](file:///c:/RnD/AKS-DevSecOps-GitOps-Observability-AI/deployment_guide.md)** into a comprehensive checklist. Verify these prerequisites are met before initiating the deployment.

---

## 1. Local Workstation Prerequisites (Windows 11 + VS Code)

Verify the following command-line tools are installed and accessible in your PowerShell environment:

- [ ] **Git:** Run `git --version` (Minimum version: `2.30+`).
- [ ] **Azure CLI:** Run `az --version` (Minimum version: `2.40+`).
- [ ] **Terraform:** Run `terraform --version` (Minimum version: `1.5+`).
- [ ] **kubectl:** Run `kubectl version --client` (Must match the target AKS cluster version, recommended Kubernetes `1.27+`).
- [ ] **Helm:** Run `helm version` (Minimum version: `3.8+`).
- [ ] **Kustomize:** Run `kustomize version` (Minimum version: `5.0+`).
- [ ] **VS Code Extensions:**
  - [ ] HashiCorp Terraform
  - [ ] Azure Pipelines
  - [ ] Kubernetes (Microsoft)
  - [ ] YAML (Red Hat)

---

## 2. Azure Subscription & Cloud Prerequisites

To prevent Terraform provisioning failures, confirm your Azure Subscription has the following configuration:

### 🔑 Permissions
- [ ] **Azure Account Role:** You must have **Owner** or **Contributor + User Access Administrator** permissions on the target subscription to manage IAM roles, create User-Assigned Managed Identities, and configure key vault policies.
- [ ] **Microsoft Entra ID (Tenant Role):** **Application Administrator** or **Cloud Application Administrator** role to configure the federated identity credentials needed for AKS Workload Identity.

### 📦 Azure Resource Providers
Run `az provider register --namespace <name>` to ensure the following resource providers are registered in your subscription:
- [ ] `Microsoft.ContainerService` (for AKS Cluster management)
- [ ] `Microsoft.Network` (for Hub/Spoke VNets, Firewall, App Gateway, and Private Endpoints)
- [ ] `Microsoft.KeyVault` (for Secrets Management)
- [ ] `Microsoft.ManagedIdentity` (for AKS Workload Identity)
- [ ] `Microsoft.Storage` (for Terraform state, Velero PV backups, and geo-redundancy)
- [ ] `Microsoft.CognitiveServices` (for Azure OpenAI Service deployments)

### 📈 Subscription Quotas & Limits
Ensure your Azure subscription has sufficient quota in your target regions (Primary: **East US**, Secondary: **West US**):
- [ ] **VM Cores:** At least 20 cores of `Standard_D` series (e.g., `Standard_D4s_v5` for AKS Node Pools).
- [ ] **Spot Cores:** Sufficient Spot cores allocated for `spotpool` node tests.
- [ ] **Public IPs:** Minimum of 4 Public IPs available (for Azure Firewall, App Gateway, Bastion, and egress NAT).
- [ ] **Azure OpenAI Access:** Your subscription must be approved for Azure OpenAI access. You must deploy standard models (such as `gpt-4` or `gpt-35-turbo`) in your region.

---

## 3. Azure DevOps Organization Prerequisites

Verify the workspace organization is set up:

- [ ] **Organization URL:** Verified access to `https://dev.azure.com/mvfimran`.
- [ ] **Project Administrator Role:** Access to create configurations.
- [ ] **Repository Structure:** Create three repositories within your Azure DevOps Project:
  - [ ] `platform-infra`
  - [ ] `platform-gitops`
  - [ ] Microservice repositories (e.g., `customer-api`, `order-api`).
- [ ] **Pipeline Parallel Jobs:** 
  > [!WARNING]
  > New Azure DevOps organizations are created with 0 parallel jobs for private pipelines, causing build runs to freeze indefinitely. Ensure you have requested the free tier grant from Microsoft or purchased at least 1 self-hosted/Microsoft-hosted parallel job.
- [ ] **Service Connection:** An active **Azure Resource Manager (ARM) Service Connection** using Workload Identity Federation configured at the Project level.
- [ ] **Personal Access Token (PAT):** A PAT generated under your account with `Code (Read & Write)` and `Pull Requests (Read & Write)` scopes.

---

## 4. Integration & Third-Party Prerequisites

- [ ] **SonarQube / SonarCloud:** A SonarQube community server instance or SonarCloud account setup, with an active project token to configure in the Application CI pipeline variables.
- [ ] **GitOps Secrets:** The Azure DevOps PAT must be ready to be injected into AKS as a Kubernetes Secret (`gitops-repo-creds`) inside the `gitops` namespace, so ArgoCD can fetch private manifests.
