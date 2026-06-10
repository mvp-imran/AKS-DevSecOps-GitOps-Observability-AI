# 🖱️ Enterprise AKS Platform: Manual GUI Deployment Guide
### Step-by-Step Azure Portal & Azure DevOps Portal Walkthrough

This guide provides a detailed, step-by-step walkthrough to deploy and configure the entire Enterprise AKS GitOps platform completely using the **Azure Portal** and **Azure DevOps Portal** graphical interfaces, with no automation code required.

---

## Part 1 — Hub-and-Spoke Networking Setup (Azure Portal)

### 1. Create the Hub Virtual Network (`vnet-hub-shared-eus`)
1. Log in to the [Azure Portal](https://portal.azure.com/).
2. In the search bar at the top, search for **Virtual networks** and select it.
3. Click **+ Create**.
4. In the **Basics** tab, configure:
   * **Subscription:** Select your target subscription.
   * **Resource Group:** Click *Create new* and name it `rg-platform-dev-eus`.
   * **Name:** `vnet-hub-shared-eus`
   * **Region:** `East US`
5. In the **IP Addresses** tab:
   * Set the IPv4 address space to `10.0.0.0/16`.
   * Under Subnets, delete any default subnets and click **+ Add subnet** to create the following:
     * `AzureFirewallSubnet` — Range: `10.0.0.0/24` *(Must be named exactly this)*
     * `AzureFirewallManagementSubnet` — Range: `10.0.1.0/24` *(Must be named exactly this)*
     * `AzureBastionSubnet` — Range: `10.0.2.0/24` *(Must be named exactly this)*
     * `GatewaySubnet` — Range: `10.0.3.0/24` *(Must be named exactly this)*
     * `snet-shared-services` — Range: `10.0.4.0/22`
     * `snet-private-endpoints` — Range: `10.0.8.0/24`
6. Click **Review + create**, and then **Create**.

### 2. Create the DEV Spoke Virtual Network (`vnet-platform-dev-eus`)
1. Go back to the **Virtual networks** screen and click **+ Create**.
2. In the **Basics** tab:
   * **Resource Group:** Select `rg-platform-dev-eus`.
   * **Name:** `vnet-platform-dev-eus`
   * **Region:** `East US`
3. In the **IP Addresses** tab:
   * Set the IPv4 address space to `10.1.0.0/16`.
   * Add the following subnets:
     * `snet-aks-system` — Range: `10.1.0.0/22`
     * `snet-aks-app` — Range: `10.1.4.0/20`
     * `snet-endpoints` — Range: `10.1.20.0/24`
     * `snet-ingress` — Range: `10.1.21.0/24`
4. Click **Review + create**, and then **Create**.

### 3. Establish Virtual Network Peering
1. Open the newly created `vnet-hub-shared-eus` resource.
2. Under **Settings** on the left menu, click **Peerings**, then click **+ Add**.
3. Configure the peering links:
   * **This virtual network (Hub):**
     * Peering link name: `peering-hub-to-dev`
     * Traffic to remote virtual network: *Allow (default)*
     * Traffic forwarded from remote virtual network: *Allow (default)*
   * **Remote virtual network (Spoke):**
     * Peering link name: `peering-dev-to-hub`
     * Virtual network deployment model: *Resource manager*
     * Subscription: Select your subscription.
     * Virtual network: Select `vnet-platform-dev-eus`.
     * Traffic to remote virtual network: *Allow (default)*
     * Traffic forwarded from remote virtual network: *Allow (default)*
4. Click **Add**. Both peerings will transition to `Connected` status.

### 4. Provision Azure Firewall (Hub Egress Gateway)
1. Search for **Firewalls** in the portal search bar and click **+ Create**.
2. In the **Basics** tab, configure:
   * **Resource Group:** `rg-platform-dev-eus`
   * **Name:** `afw-hub-shared-eus`
   * **Region:** `East US`
   * **Firewall tier:** **Standard**
   * **Firewall policy:** Click **Add new**, name it `pol-afw-shared`, select Region `East US`, and click **OK**.
   * **Virtual network:** Select **Use existing**, choose `vnet-hub-shared-eus`.
   * **Public IP address:** Click **Add new**, name it `pip-afw-hub`, and click **OK**.
3. Click **Review + create**, and then **Create**.
4. Once deployed, search for **Firewall Policies**, click on `pol-afw-shared`, and configure egress rules:
   * Select **Network rules** in the left menu, and click **+ Add a rule collection**.
   * **Name:** `allow-egress-rc`
   * **Rule collection type:** `Network`
   * **Priority:** `1000`
   * **Rule collection action:** `Allow`
   * **Rules:**
     * **Name:** `allow-all-vnet-outbound`
     * **Source type:** `IP Address`
     * **Source:** `10.0.0.0/8`
     * **Protocol:** `Any`
     * **Destination Ports:** `*`
     * **Destination Type:** `IP Address`
     * **Destination:** `*`
   * Click **Add**.
5. Go back to the **afw-hub-shared-eus** Firewall page, click **Properties** in the left menu, and note the **Private IP** (it should be `10.0.0.4` — this is used as the next hop for Spoke egress).

### 5. Provision Azure Bastion & Jumpbox VM (Secure Access)
1. **Deploy Azure Bastion Host:**
   * Search for **Bastions** in the portal search bar and click **+ Create**.
   * **Resource Group:** `rg-platform-dev-eus`
   * **Name:** `bas-hub-shared-eus`
   * **Region:** `East US`
   * **Virtual Network:** `vnet-hub-shared-eus` *(Subnet will automatically bind to `AzureBastionSubnet`)*.
   * **Public IP address:** Click **Create new**, name it `pip-bastion-hub`, and click **OK**.
   * Click **Review + create**, and then **Create**.
2. **Deploy Jumpbox VM (Secure workstation for private cluster management):**
   * Search for **Virtual machines** in the portal search bar and click **+ Create** ➔ **Azure virtual machine**.
   * **Resource Group:** `rg-platform-dev-eus`
   * **Name:** `vm-jumpbox-dev`
   * **Region:** `East US`
   * **Availability options:** *No infrastructure redundancy required*
   * **Image:** Select **Windows 11 Pro** or **Ubuntu Server 22.04 LTS**
   * **Size:** Select `Standard_D2s_v5`
   * **Administrator account:** Select password auth and set credentials (e.g., `azureuser` / secure password)
   * **Inbound port rules:** Select *None*
   * Click the **Networking** tab:
     * **Virtual network:** `vnet-hub-shared-eus`
     * **Subnet:** `snet-shared-services`
     * **Public IP:** Select **None** *(Crucial: Access is mediated entirely by Bastion)*
     * **NIC network security group:** *Basic*
   * Click **Review + create**, and then **Create**.
3. **Connect to Jumpbox:**
   * Once the VM is deployed, open the VM resource page, click **Connect** ➔ select **Bastion**.
   * Enter the credentials set during creation and click **Connect** to load the desktop/terminal session securely in your web browser.

### 6. Create and Configure Spoke Route Table (UDR)
1. Search for **Route tables** in the portal search bar and click **+ Create**.
2. Configure the basics:
   * **Resource Group:** `rg-platform-dev-eus`
   * **Region:** `East US`
   * **Name:** `rt-spoke-egress-dev`
3. Click **Review + create**, and then **Create**.
4. Once deployed, open the Route Table resource:
   * Select **Routes** on the left menu, then click **+ Add**.
     * **Route name:** `route-to-hub-firewall`
     * **Destination type:** `IP Addresses`
     * **Destination IP addresses/CIDR ranges:** `0.0.0.0/0`
     * **Next hop type:** `Virtual appliance`
     * **Next hop address:** `10.0.0.4` *(Private IP of the Hub Azure Firewall)*
     * Click **Add**.
   * Select **Subnets** on the left menu, then click **+ Associate**.
     * **Virtual network:** `vnet-platform-dev-eus`
     * **Subnet:** Select `snet-aks-system`. Click **OK**.
     * Click **+ Associate** again, select `vnet-platform-dev-eus`, and select `snet-aks-app`. Click **OK**.

### 7. Create and Configure Network Security Groups (NSGs)
1. Search for **Network security groups** in the portal search bar and click **+ Create**.
2. Configure the basics:
   * **Resource Group:** `rg-platform-dev-eus`
   * **Region:** `East US`
   * **Name:** `nsg-aks-app-dev`
3. Click **Review + create**, and then **Create**.
4. Once deployed, open the NSG resource:
   * Select **Inbound security rules** on the left menu, then click **+ Add**.
     * **Source:** `IP Addresses`
     * **Source IP addresses/CIDR ranges:** `10.1.21.0/24` *(DEV Ingress subnet range)*
     * **Source port ranges:** `*`
     * **Destination:** `Any`
     * **Destination port ranges:** `80,443,8080`
     * **Protocol:** `TCP`
     * **Action:** `Allow`
     * **Priority:** `100`
     * **Name:** `allow-http-ingress`
     * Click **Add**.
   * Click **+ Add** to add the block rule:
     * **Source:** `Any`
     * **Source port ranges:** `*`
     * **Destination:** `Any`
     * **Destination port ranges:** `*`
     * **Protocol:** `Any`
     * **Action:** `Deny`
     * **Priority:** `200`
     * **Name:** `deny-external-inbound`
     * Click **Add**.
   * Select **Subnets** on the left menu, then click **+ Associate**.
     * **Virtual network:** `vnet-platform-dev-eus`
     * **Subnet:** `snet-aks-app`
     * Click **OK**.

---

## Part 2 — Shared Services Deployment (Azure Portal)

### 1. Provision the Container Registry (ACR)
1. Search for **Container registries** in the portal and click **+ Create**.
2. In the **Basics** tab:
   * **Resource Group:** Select `rg-platform-dev-eus`.
   * **Registry name:** Enter a globally unique name, e.g., `acrplatformdeveus`.
   * **Location:** `East US`.
   * **SKU:** Select **Premium** *(Mandatory for geo-replication and private link)*.
3. In the **Replications** tab:
   * Select your target secondary region, e.g., **West US**, to configure replication.
4. In the **Networking** tab:
   * Select **Private access**.
5. Click **Review + create**, and then **Create**.
6. Once deployed, configure the **Private Endpoint**:
   * Open the Container Registry resource page.
   * Under **Settings** in the left menu, select **Networking**.
   * Click the **Private endpoint connections** tab, then click **+ Private endpoint**.
   * **Basics tab:** Resource Group: `rg-platform-dev-eus`, Name: `pe-acr-platform-dev-eus`, Region: `East US`.
   * **Resource tab:** Target sub-resource: `registry`.
   * **Virtual Network tab:** Virtual network: `vnet-platform-dev-eus`, Subnet: `snet-endpoints`.
   * **Private DNS integration:** Select **Yes** *(Integrates with `privatelink.azurecr.io`)*.
   * Click **Review + create**, and then **Create**.

### 2. Provision Azure Key Vault & Create Secrets
1. Search for **Key vaults** and click **+ Create**.
2. In the **Basics** tab:
   * **Resource Group:** Select `rg-platform-dev-eus`.
   * **Key vault name:** `kv-platform-dev-eus`.
   * **Location:** `East US`.
   * **Pricing tier:** *Standard*.
3. In the **Access configuration** tab:
   * Select **Azure role-based access control (RBAC)**.
4. In the **Networking** tab:
   * Connectivity method: Select **Disable public access**.
   * Click **+ Add** under Private Endpoints:
     * Subscription/Resource Group: `rg-platform-dev-eus`
     * Location: `East US`
     * Name: `pe-kv-platform-dev-eus`
     * Target sub-resource: `vault`
     * Virtual network: `vnet-platform-dev-eus`
     * Subnet: `snet-endpoints`
     * Private DNS integration: Select **Yes** *(Integrate with private DNS zone `privatelink.vaultcore.azure.net`)*.
5. Click **Review + create**, and then **Create**.
6. Once deployed, manually add required application secret variables:
   * Open your **kv-platform-dev-eus** resource page.
   * Scroll down the left menu to **Objects** and select **Secrets**.
   * Click **+ Generate/Import**.
   * Configure:
     * **Upload options:** `Manual`
     * **Name:** `prod-db-password`
     * **Secret value:** Enter a secure password string.
     * Click **Create**.
   * Click **+ Generate/Import** again to add other integration credentials if required:
     * **Name:** `sonar-token` *(Value: Your SonarQube quality gate token)*.
     * **Name:** `openai-key` *(Value: Your Azure OpenAI Service Auth Key)*.

### 3. Provision Backup Storage Account
1. Search for **Storage accounts** and click **+ Create**.
2. In the **Basics** tab:
   * **Resource Group:** Select `rg-platform-dev-eus`.
   * **Storage account name:** Enter a globally unique name, e.g., `savelerodeveus`.
   * **Location:** `East US`.
   * **Performance:** *Standard*.
   * **Redundancy:** Select **Geo-redundant storage (GRS)**.
3. Click **Review + create**, and then **Create**.
4. Once deployed, open the Storage Account:
   * Select **Containers** under *Data storage*, click **+ Container**, and name it `velero` with Private access.
   * Configure **Network Security & Private Endpoint**:
     * Select **Networking** under *Security + networking* in the left menu.
     * Click **Firewalls and virtual networks** and change Public network access to **Disabled** or **Enabled from selected virtual networks and IP addresses**.
     * Click the **Private endpoint connections** tab, then click **+ Private endpoint**.
     * **Basics tab:** Resource Group: `rg-platform-dev-eus`, Name: `pe-sa-velero-dev-eus`, Region: `East US`.
     * **Resource tab:** Target sub-resource: `blob`.
     * **Virtual Network tab:** Virtual network: `vnet-platform-dev-eus`, Subnet: `snet-endpoints`.
     * **Private DNS integration:** Select **Yes** *(Integrates with `privatelink.blob.core.windows.net`)*.
     * Click **Review + create**, and then **Create**.

### 4. Provision Azure Application Gateway (Regional Ingress)
1. Search for **Application gateways** in the portal search bar and click **+ Create**.
2. In the **Basics** tab, configure:
   * **Resource Group:** `rg-platform-dev-eus`
   * **Application gateway name:** `appgw-platform-dev-eus`
   * **Region:** `East US`
   * **Tier:** **WAF V2**
   * **Autoscaling:** Select **Yes** (Min capacity: 1, Max capacity: 10)
   * **Virtual network:** Select `vnet-platform-dev-eus`.
   * **Subnet:** Select `snet-ingress` (`10.1.21.0/24`).
3. In the **Frontends** tab:
   * **Frontend IP address type:** `Public`
   * **Public IP address:** Click **Add new**, name it `pip-appgw-platform-dev-eus`, and click **OK**.
4. In the **Backends** tab:
   * Click **Add a backend pool**.
   * **Name:** `bp-aks-istio-ingress`
   * **Add backend pool without targets:** Select **Yes** *(Targets will be automatically assigned by the AKS Ingress Controller integration)*.
   * Click **Add**.
5. In the **Configuration** tab, click **+ Add a routing rule**:
   * **Rule name:** `rule-http-ingress`
   * **Priority:** `100`
   * **Listener tab:**
     * **Listener name:** `listener-http`
     * **Frontend IP:** `Public`
     * **Protocol:** `HTTP` *(HTTP is used for routing to the service mesh gateway which terminates mTLS)*.
     * **Port:** `80`
     * **Listener type:** `Basic`
   * **Backend targets tab:**
     * **Target type:** `Backend pool`
     * **Backend target:** Select `bp-aks-istio-ingress`.
     * **Backend settings:** Click **Add new**:
       * **Backend settings name:** `setting-http-8080`
       * **Backend protocol:** `HTTP`
       * **Backend port:** `8080` *(Target Istio ingress gateway port)*
       * Click **Add**.
   * Click **Add**.
6. Click **Review + create**, and then **Create**.

### 5. Create and Configure Azure Front Door with WAF (Global Ingress Gateway)
1. Search for **Front Door and CDN profiles** in the Azure Portal search bar and click **+ Create**.
2. Compare offerings, select **Azure Front Door**, and select **Custom create**. Click **Continue to create Front Door**.
3. In the **Basics** tab:
   * **Resource Group:** Select `rg-platform-dev-eus`.
   * **Name:** `fd-platform-ingress-dev`.
4. In the **Endpoint** tab, click **+ Add endpoint**:
   * **Endpoint name:** `endpoint-customer-api-dev` (globally unique). Click **Add**.
5. In the **Route** tab, click **+ Add route**:
   * **Route name:** `route-to-dev-appgw`.
   * **Domains:** Select your endpoint `endpoint-customer-api-dev.azurefd.net`.
   * **Origin group:** Click *Create new*:
     * **Name:** `og-dev-appgw`
     * Click **+ Add origin**:
       * **Name:** `origin-appgw`
       * **Origin type:** `Public IP address`
       * **Host name:** Select `pip-appgw-platform-dev-eus` *(The public IP created for your spoke Application Gateway)*.
       * Click **Add**.
     * Click **Create**.
   * **Forwarding protocol:** HTTPS only.
   * Click **Add**.
6. In the **Security** tab:
   * Check **Enable WAF** (Web Application Firewall).
   * Under *WAF policy*, click *Create new*. Name it `waf-fd-platform-dev`, set Mode to **Prevention**, and click *Create*.
7. Click **Review + create**, and then **Create**.

---

## Part 3 — Private AKS Cluster Provisioning (Azure Portal)

### 1. Basics & Infrastructure Setup
1. Search for **Kubernetes services** and click **+ Create** ➔ **Create a Kubernetes cluster**.
2. In the **Basics** tab:
   * **Resource Group:** `rg-platform-dev-eus`.
   * **Cluster preset configuration:** *Standard*.
   * **Kubernetes cluster name:** `aks-dev-cluster`.
   * **Region:** `East US`.
   * **Kubernetes version:** Select `1.27` or higher.
   * **Primary Node Pool VM size:** Select `Standard_D4s_v5`.

### 2. Configure Node Pools
1. Click the **Node pools** tab.
2. Update the default **`systempool`**:
   * Click on `systempool` and change the VM size to `Standard_D4s_v5`.
   * Ensure Scale method is *Manual* or *Autoscale*, set Node Count to 3.
   * Check **Enable Availability Zones** (Zones 1, 2, 3).
3. Add the application node pool (**`apppool`**):
   * Click **+ Add node pool**.
   * Name: `apppool`.
   * Mode: **User**.
   * VM Size: `Standard_D4s_v5`.
   * Scale method: **Autoscale** (Min: 2, Max: 10).
   * Zones: Select 1, 2, 3.
   * Click **Add**.
4. Add the spot node pool (**`spotpool`**):
   * Click **+ Add node pool**.
   * Name: `spotpool`.
   * Check **Enable Azure Spot instances** (Priority: *Spot*, Eviction policy: *Delete*).
   * Scale method: **Autoscale** (Min: 1, Max: 5).
   * Click the *Taints* block and add: `sku=spot:NoSchedule`.
   * Click **Add**.

### 3. Configure Networking & Security
1. Click the **Networking** tab:
   * **Network configuration:** Select **Azure CNI (Overlay)**.
   * **Network policy:** Select **Azure NPM** (or Calico).
   * **Virtual network:** Select `vnet-platform-dev-eus`.
   * **Kubernetes service address range:** `10.2.0.0/16`.
   * **Kubernetes DNS service IP address:** `10.2.0.10`.
   * **Private cluster:** Check **Enable private cluster** *(Enforces api-server endpoint isolation)*.
   * **API server authorized IP ranges:** *(Optional but recommended for direct workstation management)* Check **Enable API server authorized IP ranges** and click **+ Add IP range** to add your workstation public IP address (e.g., `203.0.113.50/32`) to allow direct connections, or add Azure DevOps hosted agents IP blocks.
2. Click the **Security** tab:
   * Check **Enable OIDC issuer**.
   * Check **Enable Workload Identity**.

### 4. Setup Integrations
1. Click the **Integrations** tab:
   * **Container registry:** Select `acrplatformdeveus` in the dropdown. This automatically configures the `AcrPull` role assignment for the cluster.
   * **Application Gateway Ingress Controller (AGIC):**
     * Check **Enable ingress controller**.
     * **Application Gateway:** Select **Use existing** and choose `appgw-platform-dev-eus` from the dropdown list. *(This automatically configures the AGIC routing loop)*.
2. Click **Review + create**, and then **Create**.

### 5. Configure Ingress Controller (AGIC) IAM Role Assignment
When AGIC is enabled, AKS automatically provisions a managed identity to sync route changes to the Application Gateway. To grant the necessary network permissions:
1. Once the cluster is deployed, search for **Managed Identities** in the portal search bar.
2. Locate the identity created for AGIC (typically named `ingressappgw-<your-cluster-name>`, e.g., `ingressappgw-aks-dev-cluster`).
3. Navigate to your Application Gateway resource page (**appgw-platform-dev-eus**).
4. Select **Access control (IAM)** in the left menu ➔ click **+ Add** ➔ select **Add role assignment**.
5. Configure:
   * **Role:** **Network Contributor**
   * **Members:** Select *Managed identity*, search and select the AGIC identity (`ingressappgw-aks-dev-cluster`).
   * Click **Review + assign**.

### 6. Configure Workload Identity Federated Credentials
To allow microservices to authenticate securely to Azure Key Vault without client secrets:
1. Search for **Managed Identities** in the Azure Portal search bar and click **+ Create**.
2. Set Resource Group: `rg-platform-dev-eus`, Name: `mi-customer-api-dev`, Region: `East US`. Click **Create**.
3. Once created, open the Managed Identity:
   * Select **Federated credentials** under Settings, then click **+ Add**.
   * **Federated credential scenario:** Select **Kubernetes accessing Azure resources**.
   * **Cluster details:** Select your subscription, Resource Group `rg-platform-dev-eus`, and AKS Cluster `aks-dev-cluster`.
   * **Namespace:** Enter `dev` (the application namespace).
   * **Service account:** Enter `customer-api-sa` (matching your microservice deployment).
   * **Name:** `fed-cred-customer-api-dev`.
   * Click **Add**.
4. Grant Key Vault permissions to the identity:
   * Open **kv-platform-dev-eus** (Key Vault) ➔ **Access control (IAM)** ➔ **+ Add role assignment**.
   * **Role:** **Key Vault Secrets User**.
   * **Members:** Select *Managed identity*, search and add `mi-customer-api-dev`.
   * Click **Review + assign**.

### 7. Configure Managed AKS Backup (Azure Portal Backup Center)
As an alternative to Velero commands, configure native Azure Backup for your cluster:
1. Open your **aks-dev-cluster** resource page in the portal.
2. Scroll to the **Operations** section in the left menu and click on **Backup**.
3. Click **Configure backup**.
4. Configure the backup details:
   * **Backup vault:** Click *Create new* if none exists. Set Name: `bkv-platform-dev-eus`, Resource Group: `rg-platform-dev-eus`.
   * **Backup policy:** Click *Create new*. Define Schedule: `Daily` at 1:00 AM, Retention: `30 days`. Name the policy `daily-aks-backup`.
   * **Storage account:** Select your storage account `savelerodeveus` and blob container `velero`.
5. Click **Validate** and then **Configure backup**. Azure will automatically deploy the backup extension and schedule snapshots.

### 8. Configure Istio Service Mesh Add-on (Azure Portal Service Mesh Integration)
As an alternative to manual Istio Helm charts, enable native Istio integration on AKS:
1. Open your **aks-dev-cluster** resource page in the portal.
2. Scroll to the **Settings** section in the left menu and click on **Service Mesh**.
3. Check the box **Enable Service Mesh** and select **Istio**.
4. In the configuration:
   * **HTTP ingress gateway:** Select **External** (this provisions a public IP load balancer to route external mesh traffic through Istio).
   * Set configuration options to default.
5. Click **Save** (Azure will automatically install the Istio control plane `istiod` and ingress gateway components into namespace `aks-istio-system`).

---

## Part 4 — Azure DevOps & GitOps Setup (DevOps Portal)

### 1. Initialize Repositories and Configure Branch Policies
1. Open your browser and navigate to your DevOps organization: `https://dev.azure.com/mvfimran`.
2. Select your Project.
3. Navigate to **Repos** on the left menu.
4. Click the repository dropdown at the top and click **New repository**:
   * Create `platform-infra` (Git).
   * Create `platform-gitops` (Git).
   * Create `customer-api` (Git).
5. Configure Branch Policies on the protected `main` branch (Phase 3.5 of the deployment plan) to enforce code review gates:
   * Select your target repository (e.g., `customer-api`) from the repository dropdown at the top.
   * Select **Branches** under *Repos* in the left menu.
   * Hover over the `main` branch, click the **three dots (...)** icon, and select **Branch policies**.
   * Configure the following policies:
     * **Require a minimum number of reviewers:** Check this box, and set the value to `1`.
     * **Check for comment resolution:** Check this box and select **Required** *(forces all discussion threads to be closed before merge)*.
     * **Build Validation:** Click **+ Add build policy** ➔ Select your application CI build pipeline from the dropdown ➔ Set Trigger to **Automatic** and Policy requirement to **Required** ➔ Click **Save**.
     * **Limit merge types:** Check this box and check **Squash merge** only *(enforces squash commits to maintain a linear git history)*.

### 2. Configure GitOps via the Azure Portal Extension (No CLI required)
Instead of installing ArgoCD via terminal Helm commands, you can deploy and configure GitOps directly from the Azure Portal:
1. Navigate back to the Azure Portal and open your **aks-dev-cluster** resource.
2. Scroll down the left menu to the **Cluster management** section, and click on **GitOps**.
3. Click **+ Create**.
4. Configure the GitOps operator settings:
   * **Configuration name:** `gitops-bootstrap`
   * **Namespace:** `gitops`
   * **Scope:** *Cluster*
   * **Operator type:** Select **Flux** or **ArgoCD** (depending on active provider subscription).
5. In the **Repository** step:
   * Repository URL: `https://dev.azure.com/mvfimran/platform-gitops`
   * Repository type: *Private*
   * Authentication: Select **Personal Access Token (PAT)**.
   * Access token: Paste your DevOps PAT token.
   * Sync interval: `5m`
6. In the **Configuration** step:
   * Path: Type `apps/` or `envs/dev/` to instruct the operator to watch your configurations.
7. Click **Review + create**, and then **Create**. 

Azure will now automatically deploy the GitOps controller onto the private cluster and sync the App-of-Apps manifests without running a single line of command-line code.

### 3. Exposing Grafana & Distributed Tracing (Jaeger) Dashboards via ArgoCD UI
Once the GitOps sync starts, ArgoCD automatically deploys the Prometheus-Operator (`kube-prometheus-stack`), Loki, and Jaeger. To access the Grafana and Jaeger GUI dashboards without kubectl command-lines:
1. **Expose Grafana:**
   * Access the ArgoCD dashboard GUI on your browser.
   * Click on the **`kube-prometheus-stack`** application block.
   * Click **App Details** (top menu) ➔ select the **Parameters** tab.
   * Scroll to locate `grafana.ingress.enabled` and set its value to `true`.
   * Locate `grafana.ingress.hosts` and input your registered domain mapping, e.g., `grafana.dev.customer-api.mvfimran.com`.
   * Click **Save** *(ArgoCD will automatically reconcile and deploy the ingress route)*.
2. **Expose Jaeger UI:**
   * In the ArgoCD dashboard GUI, click on the **`jaeger`** application block.
   * Click **App Details** (top menu) ➔ select the **Parameters** tab.
   * Scroll to locate `query.ingress.enabled` and set its value to `true`.
   * Locate `query.ingress.hosts` and input your registered domain mapping, e.g., `jaeger.dev.customer-api.mvfimran.com`.
   * Click **Save** *(ArgoCD will reconcile and deploy the ingress route, enabling access to the Jaeger UI)*.

### 4. Import the OpenCost FinOps Dashboard in Grafana GUI
To visualize OpenCost cluster expenditures (Phase 12 of the deployment plan) inside your Grafana dashboard:
1. Open your browser and navigate to the exposed Grafana URL.
2. Log in using your admin credentials.
3. In the left menu, click **Dashboards** -> click **New** -> select **Import**.
4. In the **Find and import dashboards...** input box, enter the OpenCost Dashboard ID: **`16865`** (or paste the JSON definition). Click **Load**.
5. Select **Prometheus** as the target data source in the dropdown.
6. Click **Import**. The dashboard will instantly render cost graphs displaying compute spend per pod, namespace, and team.

### 5. Auditing Compliance and Security Policies (Azure Portal)
To verify that Kyverno policies (Phase 8 of the deployment plan) are operating correctly and protecting the cluster:
1. Open your **aks-dev-cluster** resource page in the Azure Portal.
2. Under the **Settings** section in the left menu, click on **Policies**.
3. You will see a compliance dashboard displaying compliance state for your pods.
4. Click on the policy names (such as **Kubernetes cluster pods should only use allowed volume types** or **Kubernetes cluster containers should run with CPU/Memory limits**) to view the list of non-compliant pods or blocked events.

### 6. Configure Service Connections (Azure DevOps Portal)
To allow Azure DevOps pipelines to securely authenticate to Azure resources and push quality metrics, establish these connections:
1. **Azure Resource Manager (ARM) Service Connection:**
   * In your Azure DevOps Project, click on **Project settings** (gear icon) in the bottom-left corner of the sidebar.
   * Select **Service connections** under *Pipelines* in the menu.
   * Click **+ New service connection** ➔ select **Azure Resource Manager** ➔ click **Next**.
   * Select **Workload Identity federation (automatic)** ➔ click **Next**.
   * Configure details:
     * **Scope level:** `Subscription`
     * **Subscription:** Select your target subscription from the dropdown.
     * **Resource group:** Select `rg-platform-dev-eus`.
     * **Service connection name:** `sc-arm-platform-dev-eus`.
     * Check the box: **Grant access permission to all pipelines**.
   * Click **Save** to automatically register the federated credentials.
2. **SonarQube / SonarCloud Service Connection:**
   * Click **+ New service connection** again.
   * Select **SonarQube** (or **SonarCloud**) from the connection list ➔ click **Next**.
   * Configure parameters:
     * **Server URL:** Input your SonarQube instance address (e.g. `https://sonarqube.yourdomain.com`).
     * **Token:** Paste your SonarQube quality gate user token.
     * **Service connection name:** `sc-sonarqube`.
     * Check **Grant access permission to all pipelines**.
   * Click **Save**.

### 7. Create Build and GitOps Promotion Pipelines (Azure DevOps Portal)
To build microservices with CI scans and automate promotions across env directories:
1. **Create Pipeline 2 (Application CI Pipeline):**
   * In the Azure DevOps menu on the left, navigate to **Pipelines** and click **Create Pipeline**.
   * **Where is your code?** Select **Azure Repos Git**.
   * **Select a repository:** Choose your application microservice repository (e.g., `customer-api`).
   * **Configure your pipeline:** Select **Existing Azure Pipelines YAML file**.
   * **Path:** Select the branch `main` and choose your build configuration path (e.g., `/azure-pipelines-ci.yml` or `/azure-pipelines.yml`). Click **Continue**.
   * Click **Variables** in the top right to register environment variables:
     * Add `SONAR_CONNECTION` = `sc-sonarqube`
     * Add `ACR_NAME` = `acrplatformdeveus`
   * Click **Save** (do not run, or run to test).
2. **Create Pipeline 3 (GitOps Promotion Pipeline):**
   * Go back to **Pipelines** ➔ click **New pipeline**.
   * Select **Azure Repos Git** ➔ Select repository `platform-gitops`.
   * Select **Existing Azure Pipelines YAML file** ➔ Path: Choose `/azure-pipelines-promote.yml` ➔ Click **Continue**.
   * Configure Variables:
     * Add `ARM_SERVICE_CONNECTION` = `sc-arm-platform-dev-eus`
     * Add `GITOPS_REPO` = `platform-gitops`
   * Click **Save**.

---

## Part 4.5 — Observability & Azure OpenAI Integration Setup (Azure Portal)

To deploy the AIOps incident response assistant (reducing MTTR to < 2 minutes) entirely via GUI:

### 1. Provision the Azure OpenAI Service
1. In the Azure Portal search bar, search for **Azure OpenAI** and click **+ Create**.
2. Configure the basics:
   * **Resource Group:** Select `rg-platform-dev-eus`.
   * **Name:** `aoai-platform-dev-eus`.
   * **Pricing Tier:** `S0` (Standard).
3. Click **Review + create**, and then **Create**.
4. Once deployed, open the OpenAI resource and click **Go to Azure AI Studio** (or Azure OpenAI Studio).
5. In Azure AI Studio:
   * Select **Deployments** under Shared Resources in the left menu.
   * Click **+ Create new deployment**.
   * **Select a model:** Choose `gpt-35-turbo` or `gpt-4`.
   * **Model version:** Select default (latest).
   * **Deployment name:** Enter `gpt-rca-model`.
   * Click **Create**.

### 2. Deploy the AIOps Connector (Azure Function App)
1. Search for **Function App** in the Azure Portal search bar and click **+ Create**.
2. Configure the basics:
   * **Resource Group:** Select `rg-platform-dev-eus`.
   * **Function App name:** Enter a unique name, e.g., `func-aiops-connector-dev`.
   * **Runtime stack:** Select `Python` (or Node.js).
   * **Version:** Select latest stable.
   * **Region:** `East US`.
   * **Plan type:** *Consumption (Serverless)*.
3. Click **Review + create**, and then **Create**.
4. Once deployed, configure Secure Managed Identity Access:
   * Open the Function App -> select **Identity** under *Settings* in the left menu.
   * Under the **System assigned** tab, set Status to **On**. Click **Save** (confirm with Yes).
   * Note down the auto-generated **Object ID** of the Function's Identity.
5. Grant the Function App permission to query the OpenAI model:
   * Navigate back to your **aoai-platform-dev-eus** (Azure OpenAI) resource.
   * Select **Access control (IAM)** in the left menu.
   * Click **+ Add** ➔ **Add role assignment**.
   * **Role:** Select **Cognitive Services User**.
   * **Assign access to:** Select *Managed identity*, then click *+ Select members*.
   * Select your Function App `func-aiops-connector-dev`.
   * Click **Review + assign**.
6. Register the Environment Variables:
   * Open the Function App ➔ select **Configuration** under *Settings* in the left menu.
   * Click **+ New application setting** to add these keys:
     * `AZURE_OPENAI_ENDPOINT` = *The Endpoint URL copied from your Azure OpenAI Keys page.*
     * `AZURE_OPENAI_DEPLOYMENT` = `gpt-rca-model`
     * `TEAMS_WEBHOOK_URL` = *Your Microsoft Teams / Slack Channel Incoming Webhook URL.*
   * Click **Save** and then **Confirm**.
7. Create and Deploy Function Code via the Browser:
   * In the Function App page, click **Create** under the *Functions* sidebar category.
   * Select **HTTP trigger** ➔ set Name: `rca-processor` ➔ click **Create**.
   * Once created, click **Code + Test** under *Developer* in the left menu.
   * Select the code file in the dropdown (e.g. `__init__.py` for Python) and paste the following Python handler that coordinates the webhook telemetry analysis with Azure OpenAI:
     ```python
     import os
     import json
     import requests
     import azure.functions as func
     from azure.identity import DefaultAzureCredential

     def main(req: func.HttpRequest) -> func.HttpResponse:
         try:
             req_body = req.get_json()
             alert_name = req_body['alerts'][0]['labels']['alertname']
             pod_name = req_body['alerts'][0]['labels'].get('pod', 'N/A')
             namespace = req_body['alerts'][0]['labels'].get('namespace', 'N/A')
             
             # Request Token from Azure AD using System Assigned Managed Identity
             credential = DefaultAzureCredential()
             token = credential.get_token("https://cognitiveservices.azure.com/.default")
             
             # Format OpenAI Request
             openai_url = f"{os.getenv('AZURE_OPENAI_ENDPOINT')}/openai/deployments/{os.getenv('AZURE_OPENAI_DEPLOYMENT')}/chat/completions?api-version=2023-05-15"
             payload = {
                 "messages": [
                     {"role": "system", "content": "You are a professional Site Reliability Engineer. Provide Root Cause Analysis and action steps based on pod configurations and metrics."},
                     {"role": "user", "content": f"Alert: {alert_name}\nPod: {pod_name}\nNamespace: {namespace}\nExplain root cause and mitigation."}
                 ]
             }
             headers = {
                 "Authorization": f"Bearer {token.token}",
                 "Content-Type": "application/json"
             }
             
             # Query Azure OpenAI
             response = requests.post(openai_url, json=payload, headers=headers)
             rca_text = response.json()['choices'][0]['message']['content']
             
             # Send payload to MS Teams Channel Webhook
             teams_payload = {
                 "text": f"🔴 **AIOps Incident Alert**\n\n**Alert:** {alert_name}\n**Pod:** {pod_name} (Namespace: {namespace})\n\n**Azure OpenAI RCA Assistant:**\n{rca_text}"
             }
             requests.post(os.getenv('TEAMS_WEBHOOK_URL'), json=teams_payload)
             return func.HttpResponse("Successfully processed and forwarded alert.", status_code=200)
         except Exception as e:
             return func.HttpResponse(f"Error: {str(e)}", status_code=500)
     ```
   * Click **Save** and then test the execution using the **Test/Run** panel in the portal GUI.

---

## Phase 2, 3, & 4 — Replicating for QA, UAT, & PROD Environments

To deploy the subsequent QA, UAT, and PROD environments manually via the Azure Portal, repeat the configurations detailed in **Part 1**, **Part 2**, and **Part 3** with the following parameter modifications:

### 1. Networking & Security Configurations (Part 1 Repeats)
Create VNets, Subnets, Peerings, Route Tables (UDR), and NSGs for each environment:
* **QA Virtual Network:**
  * Name: `vnet-platform-qa-eus`
  * Address Space: `10.2.0.0/16`
  * Subnets: `snet-aks-system` (`10.2.0.0/22`), `snet-aks-app` (`10.2.4.0/20`), `snet-endpoints` (`10.2.20.0/24`), `snet-ingress` (`10.2.21.0/24`).
* **UAT Virtual Network:**
  * Name: `vnet-platform-uat-eus`
  * Address Space: `10.3.0.0/16`
  * Subnets: `snet-aks-system` (`10.3.0.0/22`), `snet-aks-app` (`10.3.4.0/20`), `snet-endpoints` (`10.3.20.0/24`), `snet-ingress` (`10.3.21.0/24`).
* **PROD Virtual Network:**
  * Name: `vnet-platform-prod-eus`
  * Address Space: `10.4.0.0/16`
  * Subnets: `snet-aks-system` (`10.4.0.0/22`), `snet-aks-app` (`10.4.4.0/20`), `snet-endpoints` (`10.4.20.0/24`), `snet-ingress` (`10.4.21.0/24`).
* **Peering & UDR Rules:** Set up peerings between each new spoke VNet and `vnet-hub-shared-eus`. Associate a custom Route Table (`rt-spoke-egress-qa`, `rt-spoke-egress-uat`, `rt-spoke-egress-prod`) pointing `0.0.0.0/0` to the Firewall IP `10.0.0.4`.
* **NSG Rules:** Create Network Security Groups (`nsg-aks-app-qa`, `nsg-aks-app-uat`, `nsg-aks-app-prod`) for the `snet-aks-app` subnet of each spoke, allowing inbound HTTP/HTTPS from the respective local `snet-ingress` subnet and denying all other direct inbound traffic.

### 2. Service & Cluster Provisioning (Part 2 & 3 Repeats)
Provision resources inside their respective resource groups (`rg-platform-qa-eus`, `rg-platform-uat-eus`, `rg-platform-prod-eus`):
* **Azure Key Vault:** Create vaults named `kv-platform-qa-eus`, `kv-platform-uat-eus`, and `kv-platform-prod-eus` with public access disabled and Private Endpoints mapped to local `snet-endpoints`. Import quality-gate and application secrets (e.g., `prod-db-password` in the PROD key vault).
* **Backup Storage:** Create accounts named `saveleroqaeus`, `savelerouateus`, and `saveleroprodeus` with GRS replication, container `velero`, and Private Endpoints configured to block public access.
* **Application Gateways:** Create regional application gateways named `appgw-platform-qa-eus`, `appgw-platform-uat-eus`, and `appgw-platform-prod-eus` in each spoke `snet-ingress` subnet, configuring backend pools for Istio ingress targets.
* **Azure Front Door Routes:** Add endpoints and routes mapping your UAT and PROD application domain names to the public IPs of `appgw-platform-uat-eus` and `appgw-platform-prod-eus`.
* **AKS Clusters:**
  * Create clusters named `aks-qa-cluster`, `aks-uat-cluster`, and `aks-prod-cluster`.
  * Ensure each is private, overlay CNI, and has `systempool`, `apppool`, and `spotpool` pools defined.
  * Enable OIDC and Workload Identity.
  * Enable the **Application Gateway Ingress Controller (AGIC)** checkbox under *Integrations*, linking each cluster to its respective environment Application Gateway (e.g., `appgw-platform-qa-eus` for the QA cluster).
  * Configure **API server authorized IP ranges** to allow secure access for your deployment workstations or pipeline pools.

### 3. Azure DevOps & GitOps Configuration (Part 4 Repeats)
* **Service Connections:** Create separate ARM Service Connections (`sc-arm-platform-qa-eus`, `sc-arm-platform-uat-eus`, `sc-arm-platform-prod-eus`) in the Azure DevOps Portal to target each environment's resource group.
* **GitOps operator Configurations:** For each new cluster, configure GitOps under the AKS **GitOps** blade:
  * **For QA Cluster:** Set Path to `envs/qa/` (or `apps/qa-apps.yaml`).
  * **For UAT Cluster:** Set Path to `envs/uat/` (or `apps/uat-apps.yaml`).
  * **For PROD Cluster:** Set Path to `envs/prod/` (or `apps/prod-apps.yaml`).
* **Pipelines Setup:** Point environment promotion variables in Pipeline 3 (GitOps Promotion Pipeline) to target `envs/qa`, `envs/uat`, and `envs/prod` directories based on approvals (PR validations for UAT and PROD).
