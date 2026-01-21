terraform {
  required_providers {
    minikube = {
      source = "scott-the-programmer/minikube"
      version = "0.4.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}

provider "minikube" {
  kubernetes_version = "v1.30.0"
}

# 1. Define the Data Structure (Clients and Environments)
variable "client_config" {
  type = map(list(string))
  default = {
    airbnb    = ["dev", "prod"]
    nike      = ["dev", "qa", "prod"]
    mcdonalds = ["dev", "qa", "beta", "prod"]
  }
}

# 2. Determine Scope based on Workspace
# If workspace is "default", we default to empty or error out. 
# We expect workspace to be "airbnb", "nike", or "mcdonalds".
locals {
  current_client = terraform.workspace
  
  # Look up the environments for the current workspace
  # If workspace doesn't match a client key, return empty list (safe fallback)
  environments = lookup(var.client_config, local.current_client, [])
}

# 3. Provision Clusters (Only for the active client)
resource "minikube_cluster" "cluster" {
  for_each = toset(local.environments)

  driver       = "docker"
  cluster_name = "${local.current_client}-${each.key}" # e.g. airbnb-dev
  
  # Increased memory to 1600mb to prevent Odoo Crashes
  memory       = "1600mb"
  cpus         = 2
  
  # Network settings
  cni = "bridge"
  addons = [
    "ingress",
    "default-storageclass",
    "storage-provisioner"
  ]
}

# 4. Deploy Odoo (Using the script)
resource "null_resource" "odoo_deploy" {
  for_each = minikube_cluster.cluster

  depends_on = [minikube_cluster.cluster]

  triggers = {
    cluster_id  = each.value.cluster_name
    # Update hash to force re-run when script changes
    script_hash = filesha256("${path.module}/scripts/deploy_odoo.sh")
  }

  provisioner "local-exec" {
    # 1. Pass data securely via Environment Variables
    environment = {
      CLUSTER_NAME = each.value.cluster_name
      CLIENT       = local.current_client
      ENV          = each.key
      DOMAIN       = "odoo.${each.key}.${local.current_client}.local"
      # Terraform handles the multiline strings correctly here
      KUBE_CERT    = minikube_cluster.cluster[each.key].client_certificate
      KUBE_KEY     = minikube_cluster.cluster[each.key].client_key
    }

    # 2. Run the script WITHOUT passing arguments
    # The script now reads the environment variables defined above
    command = "bash ./scripts/deploy_odoo.sh"
  }
}