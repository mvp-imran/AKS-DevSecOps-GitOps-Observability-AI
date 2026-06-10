# 🔐 Project Credentials Vault
### Secure Credentials & Environment Variables Template

Use this file locally to record your subscription credentials, service names, and integration tokens. 

> [!WARNING]
> Do NOT commit this file to any public Git repository once actual passwords or private tokens are populated. Add this file to your `.gitignore` if needed.

---

## 1. Microsoft Azure Portal & Subscription Configuration

| Variable | Target Resource / Purpose | Value |
| :--- | :--- | :--- |
| **Azure Portal Username** | Azure Console login | |
| **Azure Portal Password** | Azure Console login | |
| **Subscription ID** | Active Azure subscription identifier | |
| **Tenant ID** | Entra ID Directory identifier | |
| **Client ID (SPN)** | Client ID for Terraform runner SPN (optional) | |
| **Client Secret (SPN)** | Client Secret for Terraform runner SPN (optional) | |

---

## 2. Azure DevOps Configuration

| Variable | Target Resource / Purpose | Value |
| :--- | :--- | :--- |
| **Organization URL** | DevOps instance endpoint (e.g. `https://dev.azure.com/mvfimran`) | `https://dev.azure.com/mvfimran` |
| **Project Name** | Project containing repos and pipelines | |
| **DevOps Username** | User account executing pipelines | |
| **DevOps Password / PAT** | User password for manual Git pulls | |
| **Personal Access Token (PAT)** | Pipeline promotion & ArgoCD pull authentication | |
| **ARM Service Connection Name** | Service connection name in Azure DevOps | |

---

## 3. Kubernetes & ArgoCD Configuration

| Variable | Target Resource / Purpose | Value |
| :--- | :--- | :--- |
| **AKS Cluster Name** | Development cluster name | `aks-dev-cluster` |
| **Resource Group (AKS)** | Resource group containing AKS | `rg-platform-dev-eus` |
| **ArgoCD Server URL** | Dashboard ingress endpoint | `https://localhost:8080` (Local Port-Forward) |
| **ArgoCD Admin Password** | Generated bootstrap admin password | |

---

## 4. Integration Tokens & Endpoints (SecOps & AIOps)

| Variable | Target Resource / Purpose | Value |
| :--- | :--- | :--- |
| **SonarQube Endpoint** | Code Quality server API endpoint | |
| **SonarQube Token** | Token to push scan results in Pipeline 2 | |
| **Azure OpenAI Endpoint** | AIOps assistant API base URL | |
| **Azure OpenAI Key** | AIOps assistant API authentication key | |
