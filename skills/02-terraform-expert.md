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
