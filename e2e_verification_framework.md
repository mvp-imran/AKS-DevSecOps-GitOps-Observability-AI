# 🌐 End-to-End (E2E) Platform Verification Framework
### Assuring Zero-Trust Networking, Policy Compliance, Observability, and DR Resiliency

This framework defines the verification checklist and outlines two distinct validation approaches (**Automated Scripting** and **Manual Interactive Testing**) to guarantee that the deployed enterprise AKS landing zone works as specified.

---

## 📋 Complete E2E Platform Verification Checklist

| Test ID | Area | Verification Target | Automated Verification | Manual Verification | Success Criteria | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **TC-01** | Connectivity | Azure Private DNS Resolution | `Resolve-DnsName` | `nslookup` via Jumpbox | Vault/ACR resolve to internal `10.1.20.X` IPs | [ ] |
| **TC-02** | Security | Egress Firewall Block | Outbound `wget` block test | Curl facebook.com from pod | Outbound connections to non-whitelisted sites time out | [ ] |
| **TC-03** | Security | Admission Control (Kyverno) | Deploy `:latest` image tag | Create non-compliant YAML | API server rejects manifest with webhook exception | [ ] |
| **TC-04** | Security | Secrets CSI Integration | Exec file check in container | Check pod mounts via CLI | Secret loaded from Key Vault is readable in pod filesystem | [ ] |
| **TC-05** | GitOps | GitOps Sync Loop | Query ArgoCD Application API | Check Sync state in ArgoCD UI | Drifted configs are auto-synced back to target state | [ ] |
| **TC-06** | Observability | Prometheus & Grafana | Query Prometheus svc port | Access Grafana portal in GUI | Metrics dashboard displays CPU, Memory, and Pod Count | [ ] |
| **TC-07** | Observability | Loki Log Collection | Assert Loki svc endpoint | Search logs in Grafana Explore | Queries like `{namespace="dev"}` render logs | [ ] |
| **TC-08** | Observability | Jaeger Tracing | Assert Jaeger query service | Query traces in Jaeger UI | Tracing spans are mapped for inter-service transactions | [ ] |
| **TC-09** | FinOps | Load Scaling (HPA/VPA) | Poll HPA resources | Generate CPU stress via pod | HPA scales replicas up under load and scales down | [ ] |
| **TC-10** | DR | Multi-Region Failover | Check Front Door endpoints | Stop primary App Gateway | Traffic shifts to secondary (West US) origin automatically | [ ] |
| **TC-11** | AIOps | Azure OpenAI Assistant | Trigger simulated crash | Check teams alerts channel | GPT-4 Root Cause Analysis message delivered in < 2 mins | [ ] |

---

## ⚡ Approach 1: Fully Automated Verification (Script-Based)

To execute automated platform verification from your Bastion Jumpbox VM:

### 1. Pre-requisites
Ensure your active PowerShell session is authenticated with Azure and connected to the AKS cluster:
```powershell
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
az aks get-credentials --resource-group rg-platform-dev-eus --name aks-dev-cluster --overwrite-existing
```

### 2. Run the Test Suite
Execute the testing runner script located at the workspace root:
```powershell
.\run-e2e-tests.ps1 `
  -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
  -ResourceGroupName "rg-platform-dev-eus" `
  -ClusterName "aks-dev-cluster" `
  -KeyVaultName "kv-platform-dev-eus" `
  -AcrName "acrplatformdeveus" `
  -Namespace "dev"
```

### 3. Expected Output Scorecard
The script will return a real-time compliance scorecard:
```text
=========================================================================
                      E2E VERIFICATION SCORECARD                         
=========================================================================
1. Azure CLI Authentication & Cluster Context : [ PASS ]
2. Private Endpoint DNS Resolution (ACR & Key Vault) : [ PASS ]
3. Egress Traffic Isolation (Firewall Block) : [ PASS ]
4. Admission Control Rules (Kyverno Block Policies) : [ PASS ]
5. Workload Identity & CSI Secret Mounting : [ PASS ]
6. GitOps Reconciliation & ArgoCD Status : [ PASS ]
7. Observability Backend Endpoint Health : [ PASS ]

Result: 7 / 7 Tests Passed.
=========================================================================
```

---

## 🖱️ Approach 2: Manual Interactive Verification (GUI & CLI Runbook)

Follow this runbook to manually verify each component using the Azure Portal, ArgoCD Console, Grafana, and CLI outputs.

### Step 1: Egress Networking & Isolation Verification
1.  **Verify Outbound Denials:** Connect to the private jumpbox VM, start a shell inside a pod, and curl a blocked domain:
    ```bash
    kubectl run shell-test --image=busybox -it --rm --restart=Never -- sh
    # Inside the pod:
    wget --timeout=5 -qO- https://www.facebook.com
    ```
    *   **Success Criteria:** Command must hang or time out.
2.  **Verify Inbound Blocking (NSG):** Attempt to connect to the AKS App Node Pool IP address directly from outside the network.
    *   **Success Criteria:** Direct connection fails, confirming that the Spoke NSG (`nsg-aks-app-dev`) blocks all ingress not routed via the Application Gateway subnet.

### Step 2: Admission Policy Enforcement (Kyverno)
1.  **Deploy a Non-Compliant Pod:** Attempt to deploy a pod without CPU/Memory requests or limits:
    ```bash
    kubectl run test-policy --image=nginx:1.25
    ```
    *   **Success Criteria:** The Kubernetes API server must block the creation and return the Kyverno webhook exception:
        `Error from server: admission webhook "validate.kyverno.svc" denied the request: CPU and Memory resource limits are mandatory.`

### Step 3: Key Vault CSI Provider Mount check
1.  **Retrieve Secret values:** Check the filesystem of your running workload pod:
    ```bash
    kubectl exec test-secret-pod -n dev -- ls /mnt/secrets/
    ```
    *   **Success Criteria:** The secret name (e.g. `prod-db-password`) must be present as a file. Cat the file (`cat /mnt/secrets/prod-db-password`) to verify it prints the secure value stored inside the Key Vault.

### Step 4: GitOps Drift Detection (ArgoCD UI)
1.  **Open ArgoCD UI:** Log in using the admin credentials.
2.  **Delete a Resource:** Delete an active service manually:
    ```bash
    kubectl delete service customer-api-service -n dev
    ```
    *   **Success Criteria:** In the ArgoCD UI, watch the resource immediately transition to `OutOfSync`, trigger auto-reconciliation, and re-create the service back to a green `Synced` state.

### Step 5: Observability Verification (Grafana / Jaeger)
1.  **Access Grafana Dashboards:** Log in, navigate to **Dashboards** ➔ open **OpenCost Dashboard (ID: 16865)**.
    *   **Success Criteria:** Resource cost graphs must load correctly, showing compute expenditures per namespace.
2.  **Verify Log Flow (Loki):** In Grafana ➔ select **Explore** ➔ select **Loki** ➔ run `{namespace="dev"}`.
    *   **Success Criteria:** Standard error and standard out streams from your running pod containers must render dynamically.
3.  **Trace Application Requests (Jaeger):** Open the Jaeger tracing UI, select service `customer-api`, and click **Find Traces**.
    *   **Success Criteria:** Confirm inter-service HTTP spans and database queries are completely mapped and visualized.

### Step 6: Disaster Recovery Failover Simulation (Azure Front Door)
1.  **Initiate Primary Region Outage:** In the Azure Portal, open the Primary Application Gateway `appgw-platform-dev-eus` and click **Stop** in the top menu.
2.  **Verify Automatic Failover:** In your browser, open a new tab and hit your global endpoint:
    `https://endpoint-customer-api-dev.azurefd.net/healthz`
    *   **Success Criteria:** The page must remain responsive and return healthy statuses.
3.  **Check Front Door Routing Metrics:** In the Front Door profile metrics panel, check the routing split. Traffic should shift entirely from the East US origin to the West US origin.
4.  **Restore Primary Gateway:** In the portal, click **Start** on `appgw-platform-dev-eus` and verify traffic returns back to the Primary region.
