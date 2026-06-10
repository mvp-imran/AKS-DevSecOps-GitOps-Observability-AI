# Enterprise Microservices Platform on Azure AKS

### Complete GitOps + DevSecOps + FinOps + AI + Observability Platform

### Based on Microsoft Cloud Adoption Framework (CAF) & Azure Landing Zone

This guide assumes **zero prior experience** and is designed as a blueprint for building a production-grade platform supporting hundreds of microservices.

---

# Phase 1 — Define the Target State

## Business Goal

Build a platform supporting:

- DEV
- QA
- UAT
- PROD

with:

- AKS
- Azure DevOps
- GitOps
- DevSecOps
- FinOps
- Observability
- Backup
- Disaster Recovery
- AI-powered Operations
- Enterprise Security

---

# High-Level Architecture

```text
                                   Internet
                                       │
                         Azure Front Door + WAF
                                       │
                          Application Gateway
                                       │
                ┌──────────────────────┴─────────────────────┐
                │                                            │
        PROD AKS Cluster                           UAT AKS Cluster
                │                                            │
                └──────────────────────┬─────────────────────┘
                                       │
                                Shared Services
                                       │
      ┌────────────┬─────────────┬─────────────┬─────────────┐
      │            │             │             │
     ACR       KeyVault       ArgoCD      Monitoring
      │            │             │             │
      └────────────┴─────────────┴─────────────┘
                                       │
                            DEV AKS / QA AKS
                                       │
                             Azure DevOps
                                       │
                             Developers
```

---

# Recommended Landing Zone

Microsoft recommends separating workloads into subscriptions.

## Management Group Structure

```text
Tenant Root
│
├── Platform
│
├── Connectivity
│
├── Identity
│
└── Landing Zones
      │
      ├── DEV
      ├── QA
      ├── UAT
      └── PROD
```

This aligns with Microsoft's CAF guidance.

Use separate subscriptions:

| Subscription    | Purpose             |
| --------------- | ------------------- |
| Shared Services | ACR, KeyVault       |
| DEV             | Development         |
| QA              | Testing             |
| UAT             | Business validation |
| PROD            | Production          |

---

# Phase 2 — Network & Security Architecture

Microsoft Landing Zone uses a Hub-and-Spoke topology to separate management services from workload environments, enforcing strict boundary isolation.

## Hub Virtual Network (`vnet-hub-shared-eus`)
* **Address Space:** `10.0.0.0/16`
* **Subnets:**
  * `AzureFirewallSubnet` (`10.0.0.0/24`): Dedicated to Azure Firewall Premium for centralized egress/ingress filtering.
  * `AzureFirewallManagementSubnet` (`10.0.1.0/24`): Dedicated management plane if forced tunneling is enabled.
  * `AzureBastionSubnet` (`10.0.2.0/24`): Secure management access endpoint for VM resources.
  * `GatewaySubnet` (`10.0.3.0/24`): ExpressRoute/VPN Gateway for on-premises connectivity.
  * `snet-shared-services` (`10.0.4.0/22`): Hosts shared registries (ACR), orchestration VMs, and key vaults.
  * `snet-private-endpoints` (`10.0.8.0/24`): Dedicated subnet for Private Endpoints of shared resources.

## Spoke Virtual Networks
To prevent IP overlapping, each environment spoke VNet is assigned a unique `/16` range, and subnets are sized using CIDR ranges to allocate sufficient IP capacity for AKS pod density (utilizing Azure CNI Overlay).

### 1. DEV Spoke VNet (`vnet-platform-dev-eus`)
* **Address Space:** `10.1.0.0/16`
* **Subnets:**
  * `snet-aks-system` (`10.1.0.0/22` — 1024 IPs): Dedicated node/pod space for core cluster services.
  * `snet-aks-app` (`10.1.4.0/20` — 4096 IPs): Primary subnet for microservice workloads.
  * `snet-endpoints` (`10.1.20.0/24` — 256 IPs): Private endpoints for Dev-specific resources.
  * `snet-ingress` (`10.1.21.0/24` — 256 IPs): Integration subnet for Azure Application Gateway.

### 2. QA Spoke VNet (`vnet-platform-qa-eus`)
* **Address Space:** `10.2.0.0/16`
* **Subnets:**
  * `snet-aks-system` (`10.2.0.0/22` — 1024 IPs)
  * `snet-aks-app` (`10.2.4.0/20` — 4096 IPs)
  * `snet-endpoints` (`10.2.20.0/24` — 256 IPs)
  * `snet-ingress` (`10.2.21.0/24` — 256 IPs)

### 3. UAT Spoke VNet (`vnet-platform-uat-eus`)
* **Address Space:** `10.3.0.0/16`
* **Subnets:**
  * `snet-aks-system` (`10.3.0.0/22` — 1024 IPs)
  * `snet-aks-app` (`10.3.4.0/20` — 4096 IPs)
  * `snet-endpoints` (`10.3.20.0/24` — 256 IPs)
  * `snet-ingress` (`10.3.21.0/24` — 256 IPs)

### 4. PROD Spoke VNet (`vnet-platform-prod-eus`)
* **Address Space:** `10.4.0.0/16`
* **Subnets:**
  * `snet-aks-system` (`10.4.0.0/22` — 1024 IPs)
  * `snet-aks-app` (`10.4.4.0/20` — 4096 IPs)
  * `snet-endpoints` (`10.4.20.0/24` — 256 IPs)
  * `snet-ingress` (`10.4.21.0/24` — 256 IPs)

---

## Network Security & Isolation Policy

```text
  ┌─────────────────┐             ┌─────────────────┐
  │   Spoke VNet    │             │    Hub VNet     │
  │  (AKS Clusters) ├─Peering────►│ (Azure Firewall)│
  │                 │◄────────────┤                 │
  └────────┬────────┘             └────────┬────────┘
           │                               │
       Route Table                     NSG Enforced
   (0.0.0.0/0 -> FW IP)           (Least Privilege)
```

### 1. Ingress & Traffic Routing
* **UDR (User Defined Routes):** A route table will be attached to each Spoke subnet. A default route `0.0.0.0/0` redirects all outbound internet traffic to the private IP of the Azure Firewall in the Hub (`10.0.0.4`).
* **Private Link Only:** All databases, storage accounts, Key Vaults, and Container Registries will have public access disabled and Private Endpoints mapped to `snet-endpoints`.

### 2. Network Security Groups (NSGs)
* Every subnet will be associated with an NSG implementing the Principle of Least Privilege:
  * **Ingress Subnets:** Allow `80`/`443` inbound from the internet (via App Gateway WAF).
  * **App Node Pool Subnets:** Block all direct inbound connections from outside the VNet. Only accept ingress forwarded from `snet-ingress` on targeted application ports.
  * **System Node Pool Subnets:** Only accept management traffic from the Hub subnet.

---


# Phase 3 — Repository Strategy

Create Azure DevOps Project.

## Repositories

### Infrastructure

```text
platform-infra
```

Contains:

```text
terraform
landing-zone
networking
aks
security
```

---

### GitOps

```text
platform-gitops
```

Contains:

```text
dev
qa
uat
prod
```

---

### Microservices

```text
customer-api
order-api
payment-api
notification-api
```

Each service gets its own repository.

---

# Phase 3.5 — Branching & Promotion Strategy

## 1. Application Repositories (Trunk-Based Development)

All microservice repositories (e.g., `customer-api`, `order-api`) must use Trunk-Based Development.

### Branch Structure
* `main`: Protected branch. Represents the buildable and releasable state.
* `feature/*`: Short-lived branches for development.

### Branch Policies on `main`
1. **Require pull requests:** No direct commits.
2. **Build Validation:** Run the Application CI pipeline (compile, test, SAST, Trivy fs scan) on every PR update.
3. **Approvals:** Minimum 1 reviewer approval.
4. **Merge requirements:** Merge using **Squash Merge** to maintain a clean history.

---

## 2. GitOps Repository Strategy (Environment-per-Directory)

The `platform-gitops` repository uses a **single `main` branch** containing subdirectory hierarchies.

```text
platform-gitops/
├── apps/                        # ArgoCD Application declarations (App-of-Apps)
│   ├── dev-apps.yaml
│   ├── qa-apps.yaml
│   ├── uat-apps.yaml
│   └── prod-apps.yaml
└── envs/                        # Environment configurations
    ├── dev/
    │   ├── platform/            # Shared tools (Istio, Prometheus, etc.)
    │   └── apps/                # Microservice Kustomize overlays
    │       └── customer-api/
    │           ├── kustomization.yaml
    │           └── replica-patch.yaml
    ├── qa/
    ├── uat/
    └── prod/
```

### GitOps Promotion Mechanics (Pipeline 3)

The promotion pipeline uses a service account to modify configurations in `platform-gitops` to trigger ArgoCD synchronization:

1. **Promotion to DEV (Automated):**
   * Triggered by microservice CI completion on `main`.
   * Pipeline runs `kustomize edit set image` on `envs/dev/apps/<service>/kustomization.yaml` with the new image tag `$(Build.BuildId)`.
   * Automatically commits and pushes directly to `main` with `[skip ci]`.
   
2. **Promotion to QA (Automated post-verification):**
   * Triggered after DEV sanity check/automated testing passes.
   * Pipeline updates `envs/qa/apps/<service>/kustomization.yaml` and commits directly to `main`.

3. **Promotion to UAT (Pull Request Gate):**
   * Triggered after QA verification.
   * Pipeline creates a Pull Request in Azure DevOps targeting `main`, modifying only the `envs/uat/apps/<service>/kustomization.yaml` file.
   * Merging the PR triggers ArgoCD in UAT.

4. **Promotion to PROD (CAB Approved PR):**
   * Triggered after UAT sign-off.
   * Pipeline creates a Pull Request targeting `main`, modifying `envs/prod/apps/<service>/kustomization.yaml`.
   * Requires CAB approval to merge the PR.

---

# Phase 4 — Infrastructure as Code

Use:

- Terraform
- Helm

Avoid ARM Templates.

### Deployment Order

```text
Landing Zone
↓
Networking
↓
Shared Services
↓
AKS
↓
Security
↓
GitOps
↓
Applications
```

---

# Phase 5 — AKS Architecture

## Recommended Clusters

### Option 1 (Enterprise)

| Environment | Cluster  |
| ----------- | -------- |
| DEV         | AKS-DEV  |
| QA          | AKS-QA   |
| UAT         | AKS-UAT  |
| PROD        | AKS-PROD |

Best isolation.

---

## Node Pools

### System Pool

```text
systempool
```

Hosts:

- CoreDNS
- Metrics
- ArgoCD

---

### Application Pool

```text
apppool
```

Hosts:

- Microservices

---

### Spot Pool

```text
spotpool
```

Hosts:

- CI workloads
- Batch jobs

Cost savings:

30-70%

---

# Phase 6 — GitOps Architecture

Microsoft strongly recommends GitOps on AKS.

Use:

[Argo CD](https://argo-cd.readthedocs.io?utm_source=chatgpt.com)

---

## Flow

```text
Developer
   │
   ▼
Azure Repos
   │
CI Pipeline
   │
ACR
   │
Update GitOps Repo
   │
ArgoCD
   │
AKS
```

Never deploy directly from Azure DevOps.

---

# Phase 7 — DevSecOps

## CI Pipeline

```text
Commit
↓
Build
↓
Unit Test
↓
SAST
↓
Dependency Scan
↓
Container Scan
↓
Push ACR
↓
GitOps Update
```

---

## SAST

Open-source:

### SonarQube Community

or

### CodeQL

Recommended:

SonarQube

---

## Dependency Scanning

### Trivy

Scans:

- npm
- Maven
- NuGet
- Pip

---

## Container Security

### Trivy

Scan images before pushing.

Block:

```text
Critical
High
```

vulnerabilities.

---

# Phase 8 — Kubernetes Security

Install:

### Kyverno

Microsoft customers widely use it.

Policies:

### No Latest Tags

```yaml
image:latest
```

blocked.

---

### Resource Limits Mandatory

```yaml
cpu
memory
```

required.

---

### No Privileged Containers

```yaml
privileged: true
```

blocked.

---

# Phase 9 — Secrets Management

Use:

Microsoft Azure Key Vault

with:

### AKS Workload Identity

```text
Pod
↓
Managed Identity
↓
Key Vault
```

Never store secrets:

- Git
- YAML
- Pipeline Variables

---

# Phase 10 — Observability (Open Source Cost Saving)

You requested avoiding managed services.

Recommended stack:

## Metrics

Prometheus

## Dashboards

Grafana OSS

## Logs

Loki

## Log Collection

Promtail

## Tracing

Jaeger

## Telemetry

OpenTelemetry

---

Architecture:

```text
Application
│
├── Metrics
├── Logs
├── Traces
│
▼
OpenTelemetry
│
├── Prometheus
├── Loki
└── Jaeger
```

---

## Deploy Using Helm

Install:

```text
kube-prometheus-stack
loki-stack
jaeger
```

---

Industry Standard Stack:

```text
Prometheus
Grafana
Loki
Tempo/Jaeger
OpenTelemetry
```

---

# Phase 11 — Service Mesh

Recommended:

### Istio

Provides:

- mTLS
- Traffic Routing
- Canary
- Blue/Green

Architecture:

```text
Service A
   ↔
Istio
   ↔
Service B
```

---

# Phase 12 — FinOps

Most organizations ignore this.

Implement from Day 1.

## Tagging

Every resource:

```text
Application
Environment
Owner
CostCenter
```

---

## AKS Cost Optimization

### Spot Nodes

Non-prod only.

---

### Cluster Autoscaler

Enable:

```text
0 → 10 nodes
```

---

### HPA

Horizontal Pod Autoscaler

---

### VPA

Vertical Pod Autoscaler

---

### Karpenter

(Optional)

More efficient than Cluster Autoscaler.

---

## FinOps Dashboard

Deploy:

### OpenCost

Integrates with:

- Prometheus
- Grafana

Shows:

```text
Cost per Namespace
Cost per Service
Cost per Team
```

---

# Phase 13 — Backup

Open-source recommendation:

### Velero

Backup:

```text
Namespaces
PVCs
Configs
Secrets
```

Store backups:

- Azure Blob Storage

---

Schedule:

```text
Daily
Weekly
Monthly
```

---

# Phase 14 — Disaster Recovery

## Recommended

Primary Region:

East US

Secondary Region:

West US


---

## Replicate

### ACR

Geo replication

---

### Key Vault

Geo-redundancy

---

### Storage

GRS

---

### Git

Already replicated.

---

## DR Strategy

```text
Primary Region
       │
Replication
       │
Secondary Region
```

---

# Phase 15 — Azure AI Operations

Very few organizations do this today.

## Azure OpenAI Use Cases

Use:

- Incident Summarization
- Root Cause Analysis
- Log Analysis
- Cost Optimization Recommendations
- Security Findings Analysis

Example:

```text
Prometheus Alert
↓
Azure Function
↓
Azure OpenAI
↓
Generate RCA
↓
Teams Notification
```

Potential savings:

30-50% reduction in troubleshooting effort.

---

# Phase 16 — Deployment Strategy

Use:

### Phase 1 — Dev Environment

Auto Deploy to DEV

```text
Commit to Application main
↓
Image Pushed to ACR
↓
GitOps Promotion Pipeline Updates /envs/dev/
```

---

### Phase 2 — QA Environment

Auto Deploy to QA

```text
DEV Sanity & Automation Tests Pass
↓
GitOps Promotion Pipeline Updates /envs/qa/
```

---

### Phase 3 — UAT Environment

Manual Approval & Promotion to UAT

```text
QA Verified
↓
GitOps Promotion Pipeline Creates PR for /envs/uat/
↓
PR Approved and Merged
```

---

### Phase 4 — PROD Environment

CAB Approval & Promotion to PROD

```text
UAT Approved
↓
GitOps Promotion Pipeline Creates PR for /envs/prod/
↓
CAB Review ──► PR Approved and Merged
```

---

# Phase 17 — Azure DevOps Pipelines

Pipeline 1

```text
Infrastructure (IaC)
```

Deploy:

- Network
- AKS
- Security

Triggered by changes to the `platform-infra` repo. Runs validation and plans on PRs, and `terraform apply` on merge to `main` (gated by approvals for UAT/PROD).

---

Pipeline 2

```text
Application CI
```

Build ──► SAST / Quality Gate (SonarQube) ──► Vulnerability Scan (Trivy) ──► Push to ACR

Triggered by commits to microservices' `main` branches.

---

Pipeline 3

```text
GitOps Promotion
```

* **Inputs:** Target Service, Target Environment, Image Tag
* **Actions:**
  1. Clones the `platform-gitops` repository.
  2. Updates the application's image tag in the specific environment folder using Kustomize (`kustomize edit set image`).
  3. Commits and pushes directly to `main` (for `dev` and `qa`) or creates an Azure DevOps Pull Request targeting `main` (for `uat` and `prod`).

---

# Phase 18 — Recommended Namespace Strategy

```text
dev
qa
uat
prod
```

Shared:

```text
monitoring
security
gitops
istio-system
```

---

# Phase 19 — Production Readiness Checklist

Before Go-Live:

### Security

- Private AKS
- Workload Identity
- Key Vault
- Kyverno
- Trivy

### Reliability

- Multi-AZ
- Velero
- DR Testing

### Observability

- Prometheus
- Grafana
- Loki
- Jaeger

### FinOps

- OpenCost
- Autoscaling
- Spot Nodes

### GitOps

- ArgoCD
- Git-based deployments

### AI

- Azure OpenAI RCA Assistant

---

# Recommended Final Stack (Cost-Optimized)

| Area               | Tool                         |
| ------------------ | ---------------------------- |
| CI/CD              | Azure DevOps                 |
| GitOps             | ArgoCD                       |
| Kubernetes         | AKS                          |
| IaC                | Terraform                    |
| Registry           | ACR                          |
| Security Policy    | Kyverno                      |
| Vulnerability Scan | Trivy                        |
| Code Quality       | SonarQube Community          |
| Secrets            | Azure Key Vault              |
| Metrics            | Prometheus                   |
| Dashboards         | Grafana OSS                  |
| Logs               | Loki                         |
| Traces             | Jaeger                       |
| Telemetry          | OpenTelemetry                |
| Service Mesh       | Istio                        |
| Cost Management    | OpenCost                     |
| Backup             | Velero                       |
| DR                 | Secondary Azure Region       |
| AI Operations      | Azure OpenAI                 |
| Identity           | Entra ID + Workload Identity |

### Suggested Implementation Timeline for a Beginner

1. **Week 1–2:** Landing Zone, subscriptions, networking.
2. **Week 3:** Terraform and Azure DevOps setup.
3. **Week 4:** AKS deployment.
4. **Week 5:** ArgoCD GitOps implementation.
5. **Week 6:** Security (Key Vault, Kyverno, Trivy, SonarQube).
6. **Week 7:** Observability stack (Prometheus, Grafana, Loki, Jaeger).
7. **Week 8:** Backup and DR.
8. **Week 9:** FinOps (OpenCost, autoscaling).
9. **Week 10:** Azure AI operational assistant and production readiness review.

This approach follows Microsoft CAF principles while replacing expensive managed monitoring components with proven open-source alternatives where it makes financial sense.
