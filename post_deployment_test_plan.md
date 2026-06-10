# 🧪 Post-Deployment Test & Verification Plan
### Step-by-Step Validation Guide for Enterprise AKS Landing Zone

This test plan provides step-by-step verification procedures to validate that all pillars of the Enterprise AKS Platform (Networking, GitOps, DevSecOps, Observability, FinOps, DR, and AIOps) are operating correctly after deployment.

---

## 1. Network & Isolation Boundaries Validation
Verify that spoke-to-hub egress filtering, Private Link, and Network Security Groups (NSGs) are enforced.

### Test 1.1: Egress Traffic Filtering via Hub Azure Firewall
1. Log in to your **Jumpbox VM** (`vm-jumpbox-dev`) via Azure Bastion.
2. Open a terminal and run credentials configuration to access the private cluster:
   ```powershell
   az aks get-credentials --resource-group rg-platform-dev-eus --name aks-dev-cluster
   ```
3. Deploy a temporary testing pod:
   ```bash
   kubectl run test-egress --image=busybox -it --rm --restart=Never -- sh
   ```
4. Inside the pod, attempt to connect to an allowed domain (e.g. microsoft.com or github.com):
   ```bash
   wget -qO- https://www.github.com
   ```
   * **Expected Outcome:** Returns HTML content successfully.
5. Attempt to connect to a non-whitelist domain (e.g. facebook.com):
   ```bash
   wget --timeout=5 -qO- https://www.facebook.com
   ```
   * **Expected Outcome:** Connection times out or returns a Firewall block response, confirming egress rules are working.

### Test 1.2: Private Link Resolution
From the Jumpbox, verify that DNS queries to private endpoints resolve to internal VNet IPs:
```powershell
nslookup acrplatformdeveus.azurecr.io
nslookup kv-platform-dev-eus.vault.azure.net
```
* **Expected Outcome:** IP addresses returned should be within the endpoints subnet range (`10.1.20.X`), not public IPs.

---

## 2. Shift-Left Security & Kyverno Policy Validation
Verify that Kyverno admission controller policies are actively blocking non-compliant manifests.

### Test 2.1: Disallow `latest` Image Tags
Attempt to run a pod using the `:latest` tag:
```bash
kubectl run test-latest-tag --image=nginx:latest --restart=Never
```
* **Expected Outcome:** Command is blocked by Kyverno with an admission webhook rejection error: `validation error: Image tag 'latest' is disallowed.`

### Test 2.2: Mandate CPU/Memory Resource Limits
Attempt to run a pod without defining resources:
```yaml
# test-no-resources.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-no-resources
spec:
  containers:
  - name: nginx
    image: nginx:1.25
```
Deploy the manifest:
```bash
kubectl apply -f test-no-resources.yaml
```
* **Expected Outcome:** Webhook blocks the request: `validation error: CPU and Memory resource limits are mandatory.`

### Test 2.3: Block Privileged Container Escalation
Attempt to run a pod with root escalation permissions:
```yaml
# test-privileged.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    securityContext:
      privileged: true
```
Deploy the manifest:
```bash
kubectl apply -f test-privileged.yaml
```
* **Expected Outcome:** Webhook blocks the request: `validation error: Privileged containers are disallowed.`

---

## 3. Workload Identity & Secret Access Verification
Verify that pods can fetch secrets from Key Vault using Entra ID federated credentials.

### Test 3.1: Mount Key Vault Secret via SecretProviderClass
1. Deploy a test SecretProviderClass linking to `kv-platform-dev-eus`:
   ```yaml
   apiVersion: secrets-store.csi.x-k8s.io/v1
   kind: SecretProviderClass
   metadata:
     name: azure-kv-provider
     namespace: dev
   spec:
     provider: azure
     secretObjects:
     - secretName: db-pass-secret
       type: Opaque
       data:
       - objectName: prod-db-password
         key: password
     parameters:
       usePodIdentity: "false"
       useVMManagedIdentity: "false"
       userAssignedIdentityID: "<client-id-of-mi-customer-api-dev>"
       keyvaultName: "kv-platform-dev-eus"
       cloudName: ""
       objects:  |
         array:
           - |
             objectName: prod-db-password
             objectType: secret
             objectVersion: ""
       tenantId: "<your-tenant-id>"
   ```
2. Deploy a pod referencing the SecretProviderClass:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: test-secret-pod
     namespace: dev
     labels:
       azure.workload.identity/use: "true"
   spec:
     serviceAccountName: customer-api-sa
     containers:
     - name: web
       image: nginx:1.25
       volumeMounts:
       - name: secrets-store-inline
         mountPath: "/mnt/secrets"
         readOnly: true
     volumes:
     - name: secrets-store-inline
       csi:
         driver: secrets-store.csi.k8s.io
         readOnly: true
         volumeAttributes:
           secretProviderClass: "azure-kv-provider"
   ```
3. Verify secret mounting:
   ```bash
   kubectl exec test-secret-pod -n dev -- cat /mnt/secrets/prod-db-password
   ```
   * **Expected Outcome:** Prints the secure database password value configured inside Key Vault.

---

## 4. GitOps Sync & App-of-Apps Validation
Verify that ArgoCD is monitoring and synchronizing workloads automatically.

### Test 4.1: ArgoCD State Reconciliation
1. Access the ArgoCD dashboard URL.
2. Verify that the root app (`dev-apps`) shows all child applications (`customer-api`, `monitoring`, `security`) in a green, **Synced** and **Healthy** status.
3. Manually delete a cluster resource managed by GitOps (e.g. a Service resource):
   ```bash
   kubectl delete service customer-api-service -n dev
   ```
4. Monitor the ArgoCD UI.
   * **Expected Outcome:** ArgoCD immediately detects the configuration drift and recreates the service resource to restore the GitOps target state.

---

## 5. FinOps & Autoscaling Validation
Verify that Horizontal Pod Autoscalers (HPA) and node pools auto-scale on resource load.

### Test 5.1: Workload Load Testing and HPA Scale-Out
1. Deploy a temporary load generation container:
   ```bash
   kubectl run load-generator --image=busybox --restart=Never -- sh -c "while true; do wget -q -O- http://customer-api-service.dev.svc.cluster.local; done"
   ```
2. Monitor HPA scaling metrics:
   ```bash
   kubectl get hpa customer-api-hpa -n dev -w
   ```
   * **Expected Outcome:** As CPU utilization exceeds 70%, replicas dynamically scale up from `2` towards the maximum limit of `10`.
3. Stop the load generator and verify scale-down:
   ```bash
   kubectl delete pod load-generator
   ```
   * **Expected Outcome:** After the cool-down period (~5 minutes), the replica count automatically scales back down to the baseline `2` replicas.

### Test 5.2: Cluster Node Pool Autoscaling
1. Verify node pool auto-scale activity when deployment replicas exceed current node pool core capacity:
   ```bash
   kubectl scale deployment customer-api --replicas=35 -n dev
   ```
2. Monitor node provisioning:
   ```bash
   kubectl get nodes -w
   ```
   * **Expected Outcome:** New agent nodes are provisioned in zones 1, 2, or 3, transitioning from `SchedulingDisabled` to `Ready` status.
3. Scale the deployment back to `2` replicas:
   ```bash
   kubectl scale deployment customer-api --replicas=2 -n dev
   ```
   * **Expected Outcome:** Idle nodes are de-provisioned automatically to reduce compute costs.

---

## 6. Observability Stack Integration Validation
Verify metric collection, log aggregation, and tracing backends.

### Test 6.1: Grafana Portal & Prometheus Cost Dashboards
1. Retrieve the Grafana admin password and port-forward to local machine:
   ```bash
   kubectl get secret --namespace monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
   kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
   ```
2. Navigate to `http://localhost:3000` in your web browser and log in as `admin`.
3. Open the **OpenCost Dashboard (Dashboard ID: 16865)**.
   * **Expected Outcome:** Resource utilization and cost-allocation graphs load successfully, displaying calculated expenditures per namespace and node.

### Test 6.2: Loki Log Collection
1. Inside the Grafana Dashboard, navigate to the **Explore** tab in the left sidebar.
2. Select the **Loki** data source.
3. Enter the query `{namespace="dev"}` and click **Run query**.
4. **Expected Outcome:** Application logs from `customer-api` pods are fully visible and updated in real-time.

### Test 6.3: Jaeger Distributed Tracing
1. Port-forward the Jaeger query service port:
   ```bash
   kubectl port-forward svc/jaeger-query -n monitoring 16686:16686
   ```
2. Navigate to `http://localhost:16686` in your web browser.
3. Select service `customer-api` in the search pane and click **Find Traces**.
4. **Expected Outcome:** API request spans, database operations, and inter-service HTTP request call stacks are fully traced and visualized.

---

## 7. AIOps OpenAI RCA Webhook Validation
Validate that cluster failures trigger GPT-4 troubleshooting diagnostics.

### Test 7.1: Simulate a Pod OOMKilled Incident
1. Deploy a mock crash test pod designed to consume more memory than its limit:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: oom-crash-test
     namespace: dev
   spec:
     containers:
     - name: memory-hog
       image: polendina/stress
       args: ["--vm", "1", "--vm-bytes", "250M", "--timeout", "30s"]
       resources:
         limits:
           memory: "50Mi"
         requests:
           memory: "10Mi"
   ```
2. Deploy the pod:
   ```bash
   kubectl apply -f oom-crash-test.yaml
   ```
3. Wait for the pod status to transition to `OOMKilled`.
4. Monitor the configured Microsoft Teams or Slack alerts channel.
   * **Expected Outcome:** Within 2 minutes of the crash, the channel receives an **AIOps Incident Alert** containing:
     * Alert name: `OOMKilled`
     * Pod name: `oom-crash-test`
     * **Azure OpenAI RCA Assistant:** A complete diagnosis explaining that the container requested 250M of memory but was terminated by the Linux Out-of-Memory killer due to a 50Mi limit restriction, followed by remediation actions (e.g. increase limits).

---

## 8. Service Mesh (Istio) Validation
Verify that Istio is active, routing ingress traffic, and enforcing secure mTLS communication.

### Test 8.1: Control Plane Health & Sidecar Injection
1. Verify the service mesh control plane pod status in the `aks-istio-system` (or `istio-system` if manually deployed) namespace:
   ```bash
   kubectl get pods -n aks-istio-system
   ```
   * **Expected Outcome:** The control plane manager `istiod-...` is in `Running` and healthy state.
2. Verify that application workloads are being injected with proxy sidecars:
   ```bash
   kubectl get pod -l app=customer-api -n dev -o jsonpath='{.items[*].spec.containers[*].name}'
   ```
   * **Expected Outcome:** Returns both `customer-api` and the `istio-proxy` sidecar container.

### Test 8.2: mTLS Enforcement Check
Check that default-deny peer authentication is active and mTLS is being enforced between namespaces:
1. Deploy a test pod without an Istio sidecar into a non-mesh namespace:
   ```bash
   kubectl run non-mesh-client --image=busybox -n default --restart=Never -- sleep 3600
   ```
2. Attempt to connect to a service inside the mesh `dev` namespace:
   ```bash
   kubectl exec non-mesh-client -n default -- wget -qO- --timeout=5 http://customer-api-service.dev.svc.cluster.local/healthz
   ```
   * **Expected Outcome:** The request is blocked/timed out because mTLS is enforced and the source pod does not have a sidecar proxy to authenticate.

---

## 9. Backup & Recovery (Velero) Validation
Verify that cluster backup schedules are active and backups are successfully stored in Geo-Redundant Storage (GRS).

### Test 9.1: Velero Backup Schedule and Status
1. Check the status of Velero deployment and verify that the backup storage location is online:
   ```bash
   velero backup-location get
   ```
   * **Expected Outcome:** Shows `default` backup storage location is `Available`.
2. Check that active backup schedules are registered:
   ```bash
   velero schedule get
   ```
   * **Expected Outcome:** Returns the configured schedules (e.g., `daily-backup`).
3. Manually trigger a backup to verify blob writing to storage account:
   ```bash
   velero backup create test-manual-backup --include-namespaces dev
   velero backup describe test-manual-backup
   ```
   * **Expected Outcome:** Backup transitions from `InProgress` to `Completed` with 0 errors.

---

## 10. Disaster Recovery Failover Simulation
Verify that Azure Front Door routes global user traffic around regional outages automatically.

### Test 10.1: Regional Outage Simulation & Traffic Redirection
1. In the Azure Portal, open the Primary Application Gateway `appgw-platform-dev-eus` and click **Stop** in the top menu.
2. In a PowerShell terminal on your workstation, continuously query your global Front Door endpoint:
   ```powershell
   while ($true) {
       try {
           $res = Invoke-RestMethod -Uri "https://endpoint-customer-api-dev.azurefd.net/healthz" -TimeoutSec 3
           Write-Host "$(Get-Date -Format 'HH:mm:ss') - Response: $($res.status)" -ForegroundColor Green
       } catch {
           Write-Host "$(Get-Date -Format 'HH:mm:ss') - Failed: $_" -ForegroundColor Red
       }
       Start-Sleep -Seconds 2
   }
   ```
3. **Expected Outcome:** 
   * Within seconds of stopping the primary gateway, traffic shifts from the East US origin to the West US origin.
   * The global endpoint remains responsive, returning HTTP `200` (healthy statuses) with minimal packet drop (< 3 failed requests during switch).

### Test 10.2: Failback to Primary Region
1. Restart the Primary Application Gateway `appgw-platform-dev-eus` via the Azure Portal.
2. Wait for the App Gateway backend health probes to pass (~3-5 minutes).
3. Observe the Azure Front Door routing metrics dashboard.
   * **Expected Outcome:** Traffic splits back to the primary East US region, restoring the active-active/active-passive regional preference config.

