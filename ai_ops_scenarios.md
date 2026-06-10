# Azure AI Operations (AIOps) — MTTR Reduction Scenarios

This reference document outlines the exact scenarios where the integrated Azure OpenAI operational assistant reduces the Mean Time to Resolution (MTTR) within the AKS microservices platform.

---

## 1. Application & Configuration Scenarios

### Scenario 1: Pod in `CrashLoopBackOff` due to Config Drift
* **Problem:** A developer updates `payment-api` to read a new environment variable `ENCRYPTION_KEY`, but forgets to add the corresponding secret reference in the Helm/GitOps repository. The application crashes immediately on startup.
* **Without AI MTTR: ~25 Minutes**
  1. **[0-5 Min]:** Alertmanager fires. SRE is paged.
  2. **[5-10 Min]:** SRE opens their laptop, connects to Azure VPN, and authenticates.
  3. **[10-15 Min]:** SRE runs `kubectl get pods -n prod` and identifies the crashing pod.
  4. **[15-20 Min]:** SRE runs `kubectl logs payment-api-xyz -p` to fetch previous logs. Analyzes the stack trace: `java.lang.IllegalArgumentException: Encryption key cannot be null`.
  5. **[20-25 Min]:** SRE reviews `deployment.yaml` and Key Vault to locate the missing configuration mapping.
* **With AI MTTR: < 2 Minutes**
  1. **[0-1 Min]:** Prometheus alert triggers a webhook to an Azure Function. The Function automatically runs a script gathering the last 30 lines of logs and the pod's YAML configuration, then feeds it to Azure OpenAI.
  2. **[1-2 Min]:** Azure OpenAI identifies that `payment-api` expects an environment variable `ENCRYPTION_KEY` mapped from Key Vault secret `payment-enc-key` which is missing. It posts a Teams message:
     > 🔴 **Incident:** `payment-api` is crash-looping. 
     > **RCA:** Missing Key Vault secret: `payment-enc-key`.
     > **Remediation:** Create the secret in Azure Key Vault `kv-platform-prod-eus` or update the mapping.

---

### Scenario 2: Pod `OOMKilled` (Out of Memory Termination)
* **Problem:** The `order-api` microservice experiences a sudden spike in traffic during a promotion. The memory consumption exceeds the Kubernetes manifest limits (512Mi), and the OS terminates the container with Exit Code 137 (`OOMKilled`).
* **Without AI MTTR: ~20 Minutes**
  1. **[0-5 Min]:** API Gateway reports a rise in 502/504 errors. SRE is paged.
  2. **[5-10 Min]:** SRE logs in and checks pod statuses: `kubectl describe pod order-api-xyz`. Finds `Last State: Terminated`, `Reason: OOMKilled`, `Exit Code: 137`.
  3. **[10-15 Min]:** SRE checks Grafana to confirm if it is a memory leak (linear rise) or a standard capacity issue (peak).
  4. **[15-20 Min]:** SRE manually creates a Git branch, updates `resources.limits.memory` to 1Gi in Helm `values.yaml`, opens a PR, waits for CI to pass, and merges it.
* **With AI MTTR: < 1 Minute**
  1. **[0-1 Min]:** Kube-state-metrics triggers an OOM event. The AI assistant interceptor queries Prometheus memory metrics for `order-api` over the past 2 hours.
  2. **[1 Min]:** AI determines the memory spike was due to traffic, not a leak, and posts to Teams:
     > 🟡 **Incident:** `order-api` terminated due to OOM. 
     > **RCA:** Traffic surge exceeded the 512Mi limit.
     > **Action:** Click [here] to automatically merge a GitOps PR increasing memory limit to 1Gi.

---

### Scenario 3: CPU Throttling causing API Timeouts
* **Problem:** `customer-api` has strict CPU limits set (`200m`). Under high load, the container is throttled by the Linux CFS scheduler, causing latency to jump from 50ms to 4.5s, resulting in frontend timeouts.
* **Without AI MTTR: ~35 Minutes**
  1. **[0-5 Min]:** Paged for high response times on `/profile` endpoint.
  2. **[5-15 Min]:** SRE analyzes Application Gateway and ingress logs. Identifies `customer-api` is the bottleneck.
  3. **[15-25 Min]:** SRE logs into Grafana, navigates to the Kubernetes Compute resources dashboard, searches for the container, and notices "CPU Throttling" is at 88%.
  4. **[25-35 Min]:** SRE updates the CPU limits to `500m` in Git, merges, and GitOps deploys it.
* **With AI MTTR: < 2 Minutes**
  1. **[0-1 Min]:** Prometheus alerts on high container CPU throttling.
  2. **[1-2 Min]:** The AI queries CPU usage vs. CPU limits, correlates it with the latency spike, and reports:
     > 🟠 **Incident:** `customer-api` is throttling. CPU limits are capped at `200m` while utilization is hitting the limit. 
     > **RCA:** CFS CPU Throttling is at 90%, causing thread latency.
     > **Action:** Recommend removing CPU limits (relying on requests and namespace quotas) or raising limits to `500m`.

---

## 2. Infrastructure & Access Scenarios

### Scenario 4: Broken Workload Identity Credentials
* **Problem:** SRE deploys a new version of `notification-api` that needs to read a database connection string from Azure Key Vault. However, the service account in AKS is misconfigured, causing authentication to Key Vault to fail with a `403 Forbidden` error.
* **Without AI MTTR: ~30 Minutes**
  1. **[0-10 Min]:** Pod stays in `CreateContainerConfigError` or crashes on startup.
  2. **[10-20 Min]:** SRE runs `kubectl describe pod` and inspects logs. Finds: `Failed to retrieve secrets from Key Vault: ClientId not found`.
  3. **[20-30 Min]:** SRE checks Azure Entra ID to verify if the Managed Identity is mapped to the Service Account via Federated Credentials. Finds a typo in the namespace name inside the credential subject (`dev` instead of `dev-apps`).
* **With AI MTTR: < 3 Minutes**
  1. **[0-2 Min]:** The AI engine parses Key Vault audit logs and checks the AKS ServiceAccount configuration.
  2. **[2-3 Min]:** The AI detects the mismatch and posts:
     > 🔴 **Incident:** `notification-api` failed to access Key Vault.
     > **RCA:** Typo in Entra ID Federated Credential for Managed Identity `mi-notification-api`. The federated subject is registered to namespace `dev-apps` but the pod is running in `dev`.

---

### Scenario 5: Network Security Group (NSG) / NetworkPolicy Egress Block
* **Problem:** A developer deploys a new service `payment-gateway` that needs to communicate with an external provider endpoint (`https://api.stripe.com`). However, the egress NetworkPolicy on the namespace blocks all outbound traffic by default, causing connection timeouts.
* **Without AI MTTR: ~45 Minutes**
  1. **[0-10 Min]:** Alerts trigger due to failed payment transactions.
  2. **[10-25 Min]:** SRE and developers inspect application logs. They see generic connection timeout messages: `java.net.ConnectException: Connection timed out`.
  3. **[25-35 Min]:** SRE runs ping/telnet tests from inside a debug container in the cluster to check if the destination is reachable. It fails.
  4. **[35-45 Min]:** SRE checks the namespace NetworkPolicies and realizes there is no egress rule allowing outbound traffic to the internet or Stripe's IP block.
* **With AI MTTR: < 3 Minutes**
  1. **[0-2 Min]:** The AI assistant captures the `Connection timed out` stack trace from the container log and queries the cluster's NetworkPolicies.
  2. **[2-3 Min]:** The AI correlates the connection destination (port 443) with the default-deny NetworkPolicy and reports:
     > 🔴 **Incident:** `payment-gateway` cannot connect to `api.stripe.com:443`.
     > **RCA:** Namespace NetworkPolicy `default-deny-egress` blocks all outbound traffic. No egress rule is defined for external API endpoints.
     > **Action:** Apply egress rule allowing traffic to `0.0.0.0/0` on port 443.

---

### Scenario 6: Ingress Gateway / WAF Blocking Requests (False Positive)
* **Problem:** A microservice updates its API contract to accept JSON payloads containing raw HTML (e.g. email templates). The Azure Application Gateway Web Application Firewall (WAF) triggers a SQL Injection / XSS rule and blocks the requests with `403 Forbidden`.
* **Without AI MTTR: ~40 Minutes**
  1. **[0-10 Min]:** Customer reports failures when saving templates. The application log shows no errors (requests never reached the pod).
  2. **[10-20 Min]:** Developer checks the pod logs and finds nothing. Escalates to SRE.
  3. **[20-35 Min]:** SRE logs into Azure Portal, opens Log Analytics, and writes a KQL query to inspect WAF logs (`AGWFirewallLogs`). Finds the block matching WAF rule `941130` (XSS Attack).
  4. **[35-40 Min]:** SRE adds a WAF exclusion rule or adjusts WAF policy.
* **With AI MTTR: < 3 Minutes**
  1. **[0-2 Min]:** The AI assistant (integrated with Azure Log Analytics) monitors spikes in WAF 403 blocks.
  2. **[2-3 Min]:** The AI correlates the blocked client requests with the Application Gateway logs and post:
     > 🟠 **Incident:** Sudden spike in `403 Forbidden` errors on `/api/templates`.
     > **RCA:** Azure WAF blocked requests due to false-positive trigger of Rule `941130` (XSS detection) on the request body.
     > **Action:** Click [here] to apply a WAF policy exclusion for Rule `941130` on route `/api/templates`.

---

## 3. Storage & Cluster Resources Scenarios

### Scenario 7: Persistent Volume Disk Space Exhaustion
* **Problem:** The Loki logging pod fills up its persistent volume (PV) storage disk. The pod locks up, stops accepting logs, and enters a crash loop.
* **Without AI MTTR: ~30 Minutes**
  1. **[0-5 Min]:** Monitoring dashboard goes blank (no logs). Alerts trigger for Loki unhealthy.
  2. **[5-15 Min]:** SRE runs `kubectl get pods` and describes the Loki pod. Sees `Container exited with code 1` or events showing `FailedAttachVolume`.
  3. **[15-25 Min]:** SRE runs `kubectl get pv` and runs `df -h` inside the node or container to inspect disk space. Finds usage at 100%.
  4. **[25-30 Min]:** SRE modifies the PVC manifest in Git to request a larger storage size (e.g. 50Gi -> 100Gi), triggering Azure Disk CSI driver to expand the volume.
* **With AI MTTR: < 2 Minutes**
  1. **[0-1 Min]:** Prometheus alerts on persistent volume disk usage > 90%.
  2. **[1-2 Min]:** The AI detects which PV is full, verifies that the underlying storage class supports dynamic volume expansion (`allowVolumeExpansion: true`), and alerts:
     > 🔴 **Incident:** Loki storage volume (`pvc-xxx`) is 98% full. 
     > **RCA:** Volume out of space.
     > **Action:** Click [here] to approve an automated GitOps commit expanding the volume size to 100Gi.

---

### Scenario 8: CoreDNS Resolution Failures
* **Problem:** An upstream DNS server configured in Azure VNet fails, causing the AKS internal DNS system (`CoreDNS`) to fail to resolve external names, causing all microservices to crash or timeout when calling external endpoints.
* **Without AI MTTR: ~50 Minutes**
  1. **[0-10 Min]:** Mass alerts on all external integrations failing.
  2. **[10-25 Min]:** SRE team verifies application logs. They find `java.net.UnknownHostException` across multiple services.
  3. **[25-40 Min]:** SRE checks the CoreDNS logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`. Finds `[ERROR] plugin/errors: 2 api.stripe.com. read udp ... i/o timeout`.
  4. **[40-50 Min]:** SRE discovers that the custom DNS servers configured on the Azure Hub VNet are unresponsive. Switches the DNS setting back to Azure DNS (`168.63.129.16`).
* **With AI MTTR: < 4 Minutes**
  1. **[0-2 Min]:** The AI assistant captures the `UnknownHostException` flood and analyzes CoreDNS events.
  2. **[2-4 Min]:** The AI runs diagnostic DNS checks against the VNet-configured DNS servers, detects they are unresponsive, and reports:
     > 🚨 **Critical Incident:** Cluster-wide DNS resolution failure.
     > **RCA:** CoreDNS is failing upstream forwarding because custom DNS servers (`10.0.0.5`, `10.0.0.6`) are offline.
     > **Action:** Recommend switching Azure Virtual Network DNS settings to "Default (Azure-provided DNS)".

---

## Summary of MTTR Reductions

| Scenario | Problem Type | Without AI MTTR | With AI MTTR | MTTR Reduction |
| :--- | :--- | :---: | :---: | :---: |
| **Scenario 1** | Pod CrashLoopBackOff | 25 Min | **2 Min** | **92%** |
| **Scenario 2** | OOMKilled Termination | 20 Min | **1 Min** | **95%** |
| **Scenario 3** | CPU Throttling | 35 Min | **2 Min** | **94%** |
| **Scenario 4** | Workload Identity Failure | 30 Min | **3 Min** | **90%** |
| **Scenario 5** | NetworkPolicy Egress Block | 45 Min | **3 Min** | **93%** |
| **Scenario 6** | WAF Request Blocking | 40 Min | **3 Min** | **92%** |
| **Scenario 7** | PV Storage Exhaustion | 30 Min | **2 Min** | **93%** |
| **Scenario 8** | CoreDNS Failure | 50 Min | **4 Min** | **92%** |
