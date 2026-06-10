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
