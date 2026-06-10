# Skill: Azure Landing Zone Expert

## Standards

Follow Microsoft CAF.

Management Groups:

Tenant Root
├── Platform
├── Connectivity
├── Identity
└── Landing Zones

Subscriptions:

- Shared Services
- DEV
- QA
- UAT
- PROD

## Networking

Use Hub-Spoke.

Hub:

- Azure Firewall
- Bastion
- DNS
- Shared Services

Spokes:

- DEV
- QA
- UAT
- PROD

## Security

Use:

- Private Endpoints
- NSGs
- Azure Firewall
- DDoS Protection

## Naming Convention

Use CAF naming.

Example:

rg-platform-dev
aks-dev-eastus
acrplatformprod

## Security Recommendations (Suggested)

- Disable public network access on all Key Vaults and Container Registries (Enforce Private Endpoints).
- Configure Azure Firewall Premium in IDPS Alert and Deny mode.
