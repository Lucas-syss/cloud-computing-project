# Multi-Client Kubernetes Provisioning

This project provisions Kubernetes infrastructure for multiple clients and environments using Terraform and Minikube.

## Architecture

- **Terraform**: Orchestrates the provisioning process.
- **Minikube**: Provides the Kubernetes clusters (one per environment).
- **Odoo**: The application deployed to each cluster.
- **Scripts**: Helper scripts for deployment and validation.

## Prerequisites

- Terraform >= 1.0.0
- Minikube
- Kubectl
- Docker

## Usage

1.  **Initialize Terraform**:
    ```bash
    terraform init
    ```

2.  **Apply Configuration**:
    ```bash
    terraform apply
    ```
    This will create the Minikube clusters and deploy the Odoo application.

3.  **Update /etc/hosts**:
    After applying, run the helper script to update your `/etc/hosts` file (requires sudo):
    ```bash
    sudo ./scripts/update_hosts.sh
    ```

4.  **Validate**:
    Run the validation script to check all endpoints:
    ```bash
    ./scripts/validate.sh
    ```

## Adding New Clients/Environments

Edit `variables.tf` and add the new client or environment to the `clients` map.

Example:
```hcl
"newclient" = {
  environments = ["dev"]
}
```

## Design Decisions

- **Dynamic Provisioning**: We use `null_resource` and `local-exec` to handle the dynamic creation of Minikube clusters and application deployments. This is necessary because Terraform's `kubernetes` provider does not support dynamic provider configurations for an unknown number of clusters in a single apply.
- **Isolation**: Each environment runs in its own Minikube cluster (profile), ensuring complete isolation.