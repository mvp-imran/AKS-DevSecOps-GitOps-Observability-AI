# Enterprise Azure AKS Platform: GitOps + DevSecOps + FinOps + Observability + AIOps

Welcome to the **Enterprise AKS Cloud-Native Platform Blueprint**. This repository contains a production-ready, modular architecture aligned with the **Microsoft Cloud Adoption Framework (CAF)** and the **Azure Well-Architected Framework**. 

Designed to support hundreds of microservices, it bridges the gap between infrastructure deployment and day-to-day SRE operations by embedding automation, security, cost control, and AI-driven operations directly into the platform fabric.

---

## 🏗️ Architectural Pillars

### 1. Hub-and-Spoke Private Landing Zone (IaC)
Built using modular **Terraform**, this blueprint enforces absolute isolation by separating management services from running workloads:
* **Hub VNet:** Hosts shared registry (ACR), Bastion, VPN Gateways, and Azure Firewall.
* **Environment Spokes (DEV, QA, UAT, PROD):** Standardized, non-overlapping VNets containing subnets for AKS system nodes, application nodes, private endpoints, and Application Gateway ingress controllers.
* **Secured Egress:** All spoke outbound traffic (`0.0.0.0/0`) is routed via User Defined Routes (UDR) to the Central Hub Azure Firewall.

### 2. GitOps-First Deployment (ArgoCD)
No manual configuration or direct pipeline deployment to Kubernetes:
* **Infrastructure State:** Managed via Terraform with remote backend state locking.
* **Manifest Orchestration:** Managed by ArgoCD using the **App-of-Apps pattern**.
* **Promotion Flow:** Implements a single-branch, **Environment-per-Directory** layout with Kustomize overlays. Promotes configurations across `dev` ➔ `qa` ➔ `uat` ➔ `prod` folders using automated pipelines and Pull Request gates.

### 3. Shift-Left Security & Governance (DevSecOps)
* **Pipeline Scans:** Builds run **SonarQube** code quality gates and **Trivy** filesystem/container image vulnerability scans (failing builds on High/Critical vulnerabilities).
* **Policy Enforcement:** **Kyverno** acts as admission control to block non-compliant deployments (e.g. enforcing CPU/Memory resource limits, blocking privileged access, and denying `latest` container tags).
* **Zero Secrets in Git:** Utilizing **AKS Workload Identity** federating Kubernetes ServiceAccounts directly to Entra ID User-Assigned Managed Identities, pulling credentials dynamically from **Azure Key Vault** (no static credentials).

### 4. Cost-Optimized Observability & FinOps
* **Monitoring Stack:** Avoids expensive SaaS fees by leveraging open-source monitoring: **Prometheus, Grafana OSS, Loki, Jaeger, and OpenTelemetry**.
* **Compute Optimization:** Employs **Horizontal Pod Autoscalers (HPA)**, **Vertical Pod Autoscalers (VPA)**, and **Spot node pools** (eviction policy: Delete) to run transient/CI workloads, saving 30-70% in compute cost.
* **Cost Allocation:** Implements **OpenCost** integration to output live cost metrics per namespace, pod, team, and environment.

### 5. AI Operations (Azure OpenAI)
Drastically drives down **MTTR (Mean Time to Resolution)** by ~90%:
* Prometheus alerts (such as `OOMKilled` or `CrashLoopBackOff`) fire webhooks to an Azure Function.
* The Function queries the pod status, retrieves the last 50 lines of logs from Loki, and feeds the context to **Azure OpenAI**.
* The AI returns a plain-English Root Cause Analysis (RCA) and remediation steps to the team's Slack/Teams channel in **under 2 minutes**.

---

## 📂 Repository Layout

```text
├── platform-infra/
│   └── terraform/
│       ├── modules/
│       │   ├── networking/      # Hub & Spoke VNets, Peering, Route Tables, NSGs
│       │   ├── aks/             # Private AKS Cluster, system/app/spot node pools
│       │   ├── acr/             # Premium ACR with geo-replication (DR)
│       │   ├── keyvault/        # Key Vault, Private Endpoints, DNS integrations
│       │   └── backup/          # Storage Account with GRS for Velero backups
│       └── environments/
│           ├── dev/             # DEV orchestration configurations
│           ├── qa/              # QA orchestration configurations
│           ├── uat/             # UAT orchestration configurations
│           └── prod/            # PROD orchestration configurations
├── skills/                      # Architectural Master guidelines and expert rules
├── prerequisites.md             # Multi-cloud pre-flight validation checklist
├── deployment_guide.md          # Phased installation guide (DEV, QA, UAT, PROD)
├── cred.md                      # Local credentials and variables templates log
├── ai_ops_scenarios.md          # 8 step-by-step diagnostic AIOps runbooks
└── README.md                    # This document
```

---

## 🚀 Getting Started

To prepare your local Windows 11 workstation, authenticate with Azure, configure your environment variables, and run the bootstrap deployment of the platform across DEV, QA, UAT, and PROD phases:

1. Read **[prerequisites.md](file:///c:/RnD/AKS-DevSecOps-GitOps-Observability-AI/prerequisites.md)** to verify your Azure subscription privileges and quotas.
2. Read **[deployment_guide.md](file:///c:/RnD/AKS-DevSecOps-GitOps-Observability-AI/deployment_guide.md)** and execute Part 1 to install the command-line tools (`Git`, `Azure CLI`, `Terraform`, `kubectl`, `Helm`, `Kustomize`).
3. Fill out the variable block in **Part 2** of the deployment guide and run the steps to deploy the landing zones and configure ArgoCD.

---

## 📬 Collaborate & Connect

If you want to discuss platform engineering, GitOps integrations, or automating your operations using AI:

* **Author:** Mohammad Imran (Cloud Architect & Platform Engineer)
* **LinkedIn:** [mvp-imran](https://www.linkedin.com/in/mvp-imran/)
* **Email:** opencode.imran@gmail.com
