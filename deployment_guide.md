# 🚀 Enterprise Workstation Setup & Environment Deployment Guide
### Aligned to DEV, QA, UAT, and PROD Phases (Unified Input Variable Configuration)

This guide organizes the entire platform deployment into an automated PowerShell script workflow. By defining your configuration inputs **once** at the start of your terminal session, you can run all commands across all phases without modifying raw variables inline.

---

## Part 1 — Workstation Setup (Baseline)

The easiest way to install and manage cloud-native tools on Windows 11 is using **winget** (Windows Package Manager) via PowerShell.

### 1. Install CLI Tools
Open **PowerShell** as Administrator and run the following command to install the required developer tools:

```powershell
# Install Git, Azure CLI, Terraform, kubectl, Helm, and Kustomize
winget install --id Git.Git -e --silent
winget install --id Microsoft.AzureCLI -e --silent
winget install --id HashiCorp.Terraform -e --silent
winget install --id Kubernetes.kubectl -e --silent
winget install --id Helm.Helm -e --silent
winget install --id Kubernetes.Kustomize -e --silent
```

> [!NOTE]
> Restart your PowerShell session after installation to refresh the Environment Path variables.

### 2. Configure VS Code Extensions
Open VS Code (`code .` in your workspace folder) and install the following extensions:
* **HashiCorp Terraform:** Autocomplete and linting support.
* **Azure Pipelines:** YAML pipeline definition checks.
* **Kubernetes (Microsoft):** Active cluster dashboard.
* **YAML (Red Hat):** Kubernetes manifest validations.

---

## Part 2 — Unified Deployment Variables (Active Session Setup)

> [!IMPORTANT]
> **Repository Directory Structure:** This guide assumes that the `platform-infra` (this repository) and `platform-gitops` repositories are cloned side-by-side in the same parent directory (e.g. `C:\RnD\platform-infra` and `C:\RnD\platform-gitops`).
>
> To clone them side-by-side, navigate to your parent directory (`C:\RnD`) and run:
> ```powershell
> git clone https://dev.azure.com/mvfimran/_git/platform-gitops
> git clone https://dev.azure.com/mvfimran/_git/customer-api
> ```

Copy the block below, customize the inputs with your details, and **run it once** in your active PowerShell window. All subsequent deployment steps rely on these variables.

```powershell
# =========================================================================
# GLOBAL PLATFORM DEPLOYMENT VARIABLES (EDIT ONCE)
# =========================================================================
$SUBSCRIPTION_ID = "YOUR_AZURE_SUBSCRIPTION_ID"
$TENANT_ID       = "YOUR_AZURE_TENANT_ID"
$DEVOPS_PAT      = "YOUR_AZURE_DEVOPS_PERSONAL_ACCESS_TOKEN"
$CLIENT_PREFIX   = "platform"                      # Lowercase alphanumeric prefix

# Regional deployments
$LOCATION_PRIMARY   = "eastus"
$LOCATION_SECONDARY = "westus"                     # DR Location

# Terraform State Storage Configuration
$TF_STATE_RG        = "rg-$CLIENT_PREFIX-tfstate-eus"
$TF_STATE_SA        = "sa${CLIENT_PREFIX}tfstate$($ENV:USERNAME.ToLower().Substring(0,2))12"
$TF_STATE_CONTAINER = "tfstate"
# =========================================================================
```

---

## Phase 1 — DEV Environment Deployment

### Step 1: Azure Authentication and State Storage
Ensure you are authenticated, then bootstrap the shared Terraform state storage resources:
```powershell
# Authenticate & set context
az login
az account set --subscription $SUBSCRIPTION_ID

# Create state resources
az group create --name $TF_STATE_RG --location $LOCATION_PRIMARY
az storage account create --resource-group $TF_STATE_RG --name $TF_STATE_SA --sku Standard_LRS --encryption-services blob
az storage container create --name $TF_STATE_CONTAINER --account-name $TF_STATE_SA
```

### Step 2: Provision DEV Infrastructure
```powershell
# Move to Dev environment folder
cd platform-infra/terraform/environments/dev

# Initialize backend dynamically
terraform init `
  -backend-config="resource_group_name=$TF_STATE_RG" `
  -backend-config="storage_account_name=$TF_STATE_SA" `
  -backend-config="container_name=$TF_STATE_CONTAINER" `
  -backend-config="key=dev.platform.tfstate"

# Deploy infrastructure by overriding inputs dynamically
terraform apply `
  -var="tenant_id=$TENANT_ID" `
  -var="acr_name=acr${CLIENT_PREFIX}deveus" `
  -var="keyvault_name=kv-${CLIENT_PREFIX}-dev-eus" `
  -var="velero_storage_account_name=savelero${CLIENT_PREFIX}deveus" `
  -var="cluster_name=aks-dev-cluster" `
  -var="dns_prefix=aksdev" `
  -var="location=$LOCATION_PRIMARY" `
  -var="resource_group_name=rg-platform-dev-eus" `
  -var="environment=dev" `
  -auto-approve

# Return to workspace parent directory
cd ../../../..
```

### Step 3: Connect & Setup DEV Cluster
```powershell
# Configure credentials
az aks get-credentials --resource-group rg-platform-dev-eus --name aks-dev-cluster

# Install ArgoCD GitOps Operator
kubectl create namespace gitops
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace gitops

# Inject Azure DevOps access token
kubectl create secret generic gitops-repo-creds -n gitops `
  --from-literal=username="gitops-bot" --from-literal=password="$DEVOPS_PAT" --type=Opaque
kubectl label secret gitops-repo-creds -n gitops "argocd.argoproj.io/secret-type=repository"

# Apply root App-of-Apps manifest
kubectl apply -f platform-gitops/apps/dev-apps.yaml -n gitops
```

---

## Phase 2 — QA Environment Deployment

### Step 1: Provision QA Infrastructure
```powershell
# Move to QA environment folder
cd platform-infra/terraform/environments/qa

# Initialize backend dynamically
terraform init `
  -backend-config="resource_group_name=$TF_STATE_RG" `
  -backend-config="storage_account_name=$TF_STATE_SA" `
  -backend-config="container_name=$TF_STATE_CONTAINER" `
  -backend-config="key=qa.platform.tfstate"

# Deploy QA resources
terraform apply `
  -var="tenant_id=$TENANT_ID" `
  -var="acr_name=acr${CLIENT_PREFIX}qaeus" `
  -var="keyvault_name=kv-${CLIENT_PREFIX}-qa-eus" `
  -var="velero_storage_account_name=savelero${CLIENT_PREFIX}qaeus" `
  -var="cluster_name=aks-qa-cluster" `
  -var="dns_prefix=aksqa" `
  -var="location=$LOCATION_PRIMARY" `
  -var="resource_group_name=rg-platform-qa-eus" `
  -var="environment=qa" `
  -auto-approve

# Return to workspace parent directory
cd ../../../..
```

### Step 2: Connect & Setup QA Cluster
```powershell
# Configure credentials
az aks get-credentials --resource-group rg-platform-qa-eus --name aks-qa-cluster

# Install ArgoCD GitOps Operator
kubectl create namespace gitops
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace gitops

# Inject Azure DevOps access token
kubectl create secret generic gitops-repo-creds -n gitops `
  --from-literal=username="gitops-bot" --from-literal=password="$DEVOPS_PAT" --type=Opaque
kubectl label secret gitops-repo-creds -n gitops "argocd.argoproj.io/secret-type=repository"

# Apply root App-of-Apps manifest
kubectl apply -f platform-gitops/apps/qa-apps.yaml -n gitops
```

---

## Phase 3 — UAT Environment Deployment

### Step 1: Provision UAT Infrastructure
```powershell
# Move to UAT environment folder
cd platform-infra/terraform/environments/uat

# Initialize backend dynamically
terraform init `
  -backend-config="resource_group_name=$TF_STATE_RG" `
  -backend-config="storage_account_name=$TF_STATE_SA" `
  -backend-config="container_name=$TF_STATE_CONTAINER" `
  -backend-config="key=uat.platform.tfstate"

# Deploy UAT resources
terraform apply `
  -var="tenant_id=$TENANT_ID" `
  -var="acr_name=acr${CLIENT_PREFIX}uateus" `
  -var="keyvault_name=kv-${CLIENT_PREFIX}-uat-eus" `
  -var="velero_storage_account_name=savelero${CLIENT_PREFIX}uateus" `
  -var="cluster_name=aks-uat-cluster" `
  -var="dns_prefix=aksuat" `
  -var="location=$LOCATION_PRIMARY" `
  -var="resource_group_name=rg-platform-uat-eus" `
  -var="environment=uat" `
  -auto-approve

# Return to workspace parent directory
cd ../../../..
```

### Step 2: Connect & Setup UAT Cluster
```powershell
# Configure credentials
az aks get-credentials --resource-group rg-platform-uat-eus --name aks-uat-cluster

# Install ArgoCD GitOps Operator
kubectl create namespace gitops
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace gitops

# Inject Azure DevOps access token
kubectl create secret generic gitops-repo-creds -n gitops `
  --from-literal=username="gitops-bot" --from-literal=password="$DEVOPS_PAT" --type=Opaque
kubectl label secret gitops-repo-creds -n gitops "argocd.argoproj.io/secret-type=repository"

# Apply root App-of-Apps manifest
kubectl apply -f platform-gitops/apps/uat-apps.yaml -n gitops
```

---

## Phase 4 — PROD Environment Deployment

### Step 1: Provision PROD Infrastructure
```powershell
# Move to PROD environment folder
cd platform-infra/terraform/environments/prod

# Initialize backend dynamically
terraform init `
  -backend-config="resource_group_name=$TF_STATE_RG" `
  -backend-config="storage_account_name=$TF_STATE_SA" `
  -backend-config="container_name=$TF_STATE_CONTAINER" `
  -backend-config="key=prod.platform.tfstate"

# Deploy PROD resources (enables geo-redundancy settings)
terraform apply `
  -var="tenant_id=$TENANT_ID" `
  -var="acr_name=acr${CLIENT_PREFIX}prodeus" `
  -var="keyvault_name=kv-${CLIENT_PREFIX}-prod-eus" `
  -var="velero_storage_account_name=savelero${CLIENT_PREFIX}prodeus" `
  -var="cluster_name=aks-prod-cluster" `
  -var="dns_prefix=aksprod" `
  -var="location=$LOCATION_PRIMARY" `
  -var="resource_group_name=rg-platform-prod-eus" `
  -var="environment=prod" `
  -auto-approve

# Return to workspace parent directory
cd ../../../..
```

### Step 2: Connect & Setup PROD Cluster
```powershell
# Configure credentials
az aks get-credentials --resource-group rg-platform-prod-eus --name aks-prod-cluster

# Install ArgoCD GitOps Operator
kubectl create namespace gitops
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace gitops

# Inject Azure DevOps access token
kubectl create secret generic gitops-repo-creds -n gitops `
  --from-literal=username="gitops-bot" --from-literal=password="$DEVOPS_PAT" --type=Opaque
kubectl label secret gitops-repo-creds -n gitops "argocd.argoproj.io/secret-type=repository"

# Apply root App-of-Apps manifest
kubectl apply -f platform-gitops/apps/prod-apps.yaml -n gitops
```
