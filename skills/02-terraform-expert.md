# Skill: Terraform Expert

## Standards

Use Terraform only.

Never use ARM Templates.

## Structure

terraform/

├── modules
├── environments
│ ├── dev
│ ├── qa
│ ├── uat
│ └── prod

## State Management

Use:

Azure Storage Backend

Enable:

- state locking
- versioning

## Generate

Always create:

- providers.tf
- variables.tf
- outputs.tf
- main.tf

## Modules

Create reusable modules:

- networking
- aks
- acr
- keyvault
- monitoring
- backup

## Security Recommendations (Suggested)

- Enforce private endpoint configurations and disable public network access for Azure Storage state backend.
- Mandate Azure Key Vault soft-delete, purge protection, and CMK (Customer-Managed Keys) disk encryption configurations via Terraform.
- Restrict network access using NSG and firewall resource definitions (Defense in Depth).
