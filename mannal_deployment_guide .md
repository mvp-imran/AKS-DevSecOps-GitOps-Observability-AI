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

### 4. Create and Configure Spoke Route Table (UDR)
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

### 5. Create and Configure Network Security Groups (NSGs)
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
   * **SKU:** Select **Premium** *(Premium is mandatory for geo-replication and private link connectivity)*.
3. In the **Replications** tab:
   * Select your target secondary region, e.g., **West US**, to configure replication.
4. In the **Networking** tab:
   * Select **Private access** to configure Private Endpoints later.
5. Click **Review + create**, and then **Create**.

### 2. Provision Azure Key Vault
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

### 3. Provision Backup Storage Account
1. Search for **Storage accounts** and click **+ Create**.
2. In the **Basics** tab:
   * **Resource Group:** Select `rg-platform-dev-eus`.
   * **Storage account name:** Enter a globally unique name, e.g., `savelerodeveus`.
   * **Location:** `East US`.
   * **Performance:** *Standard*.
   * **Redundancy:** Select **Geo-redundant storage (GRS)**.
3. Click **Review + create**, and then **Create**.
4. Once deployed, open the Storage Account, select **Containers** under *Data storage*, click **+ Container**, and name it `velero` with Private access.

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
   * Network configuration: **Azure CNI (Overlay)**.
   * Network policy: **Azure NPM** (or Calico).
   * Virtual network: Select `vnet-platform-dev-eus`.
   * Kubernetes service address range: `10.2.0.0/16`.
   * Kubernetes DNS service IP address: `10.2.0.10`.
   * Private cluster: Check **Enable private cluster** *(Enforces api-server endpoint isolation)*.
2. Click the **Security** tab:
   * Check **Enable OIDC issuer**.
   * Check **Enable Workload Identity**.

### 4. Setup Integrations
1. Click the **Integrations** tab:
   * **Container registry:** Select `acrplatformdeveus` in the dropdown. This automatically configures the `AcrPull` role assignment for the cluster.
2. Click **Review + create**, and then **Create**.

### 5. Configure Workload Identity Federated Credentials
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

### 6. Configure Managed AKS Backup (Azure Portal Backup Center)
As an alternative to Velero commands, configure native Azure Backup for your cluster:
1. Open your **aks-dev-cluster** resource page in the portal.
2. Scroll to the **Operations** section in the left menu and click on **Backup**.
3. Click **Configure backup**.
4. Configure the backup details:
   * **Backup vault:** Click *Create new* if none exists. Set Name: `bkv-platform-dev-eus`, Resource Group: `rg-platform-dev-eus`.
   * **Backup policy:** Click *Create new*. Define Schedule: `Daily` at 1:00 AM, Retention: `30 days`. Name the policy `daily-aks-backup`.
   * **Storage account:** Select your storage account `savelerodeveus` and blob container `velero`.
5. Click **Validate** and then **Configure backup**. Azure will automatically deploy the backup extension and schedule snapshots.

---

## Part 4 — Azure DevOps & GitOps Setup (DevOps Portal)

### 1. Initialize Repositories in Azure DevOps
1. Open your browser and navigate to your DevOps organization: `https://dev.azure.com/mvfimran`.
2. Select your Project.
3. Navigate to **Repos** on the left menu.
4. Click the repository dropdown at the top and click **New repository**:
   * Create `platform-infra` (Git).
   * Create `platform-gitops` (Git).
   * Create `customer-api` (Git).

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

### 3. Exposing Grafana & Observability Dashboards via ArgoCD UI
Once the GitOps sync starts, ArgoCD automatically deploys the Prometheus-Operator (`kube-prometheus-stack`) and Loki. To access the Grafana GUI dashboards without kubectl command-lines:
1. Access the ArgoCD dashboard GUI on your browser.
2. Click on the **`kube-prometheus-stack`** application block.
3. Click **App Details** (top menu) -> select **Parameters** tab.
4. Scroll to locate `grafana.ingress.enabled` and set its value to `true`.
5. Locate `grafana.ingress.hosts` and input your registered domain mapping, e.g., `grafana.dev.customer-api.mvfimran.com`.
6. Click **Save** (ArgoCD will automatically reconcile and deploy the ingress route, allowing you to access Grafana directly at that DNS address).

### 4. Auditing Compliance and Security Policies (Azure Portal)
To verify that Kyverno policies (Phase 8 of the deployment plan) are operating correctly and protecting the cluster:
1. Open your **aks-dev-cluster** resource page in the Azure Portal.
2. Under the **Settings** section in the left menu, click on **Policies**.
3. You will see a compliance dashboard displaying compliance state for your pods.
4. Click on the policy names (such as **Kubernetes cluster pods should only use allowed volume types** or **Kubernetes cluster containers should run with CPU/Memory limits**) to view the list of non-compliant pods or blocked events.

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
   * Open the Function App -> select **Configuration** under *Settings* in the left menu.
   * Click **+ New application setting** to add these keys:
     * `AZURE_OPENAI_ENDPOINT` = *The Endpoint URL copied from your Azure OpenAI Keys page.*
     * `AZURE_OPENAI_DEPLOYMENT` = `gpt-rca-model`
     * `TEAMS_WEBHOOK_URL` = *Your Microsoft Teams / Slack Channel Incoming Webhook URL.*
   * Click **Save** and then **Confirm**.

---

## Phase 2, 3, & 4 — Replicating for QA, UAT, & PROD Environments

To deploy the subsequent QA, UAT, and PROD environments manually via the Azure Portal, repeat the configurations detailed in **Part 1**, **Part 2**, and **Part 3** with the following parameter modifications:

### 1. Networking Configurations (Part 1 Repeats)
Create VNets, Subnets, and Peerings for each environment:
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
* **Peering & UDR Rules:** Set up peerings between each new spoke VNet and `vnet-hub-shared-eus`. Associate a custom Route Table pointing `0.0.0.0/0` to the Firewall IP `10.0.0.4`.

### 2. Service & Cluster Provisioning (Part 2 & 3 Repeats)
Provision resources inside their respective resource groups (`rg-platform-qa-eus`, `rg-platform-uat-eus`, `rg-platform-prod-eus`):
* **Azure Key Vault:** Create vaults named `kv-platform-qa-eus`, `kv-platform-uat-eus`, and `kv-platform-prod-eus` with public access disabled and Private Endpoints mapped to local `snet-endpoints`.
* **Backup Storage:** Create accounts named `saveleroqaeus`, `savelerouateus`, and `saveleroprodeus` with GRS replication.
* **AKS Clusters:**
  * Create clusters named `aks-qa-cluster`, `aks-uat-cluster`, and `aks-prod-cluster`.
  * Ensure each is private, overlay CNI, and has `systempool`, `apppool`, and `spotpool` pools defined.
  * Enable OIDC and Workload Identity.

### 3. GitOps Configuration (Part 4 Repeats)
For each new cluster, configure GitOps under the AKS **GitOps** blade:
* **For QA Cluster:** Set Path to `envs/qa/` (or `apps/qa-apps.yaml`).
* **For UAT Cluster:** Set Path to `envs/uat/` (or `apps/uat-apps.yaml`).
* **For PROD Cluster:** Set Path to `envs/prod/` (or `apps/prod-apps.yaml`).
