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
    tls = {
      source = "hashicorp/tls"
      version = ">= 4.0.0"
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
locals {
  current_client = terraform.workspace
  # Look up the environments for the current workspace
  environments = lookup(var.client_config, local.current_client, [])
}

# 3. Provision Clusters (Only for the active client)
resource "minikube_cluster" "cluster" {
  for_each = toset(local.environments)

  driver       = "docker"
  cluster_name = "${local.current_client}-${each.key}"
  
  # Memory increased to prevent Odoo crashes
  memory       = "1600mb"
  cpus         = 2
  
  cni = "bridge"
  addons = [
    "ingress",
    "default-storageclass",
    "storage-provisioner"
  ]
}

# 4. Generate TLS Certificates
resource "tls_private_key" "key" {
  for_each  = toset(local.environments)
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "cert" {
  for_each        = toset(local.environments)
  private_key_pem = tls_private_key.key[each.key].private_key_pem

  subject {
    common_name  = "odoo.${each.key}.${local.current_client}.local"
    organization = "Cloud Platform Engineering"
  }

  validity_period_hours = 8760 # 1 Year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# 5. Deploy Odoo (Using the script)
resource "null_resource" "odoo_deploy" {
  for_each = minikube_cluster.cluster

  depends_on = [minikube_cluster.cluster]

  triggers = {
    cluster_id  = each.value.cluster_name
    script_hash = filesha256("${path.module}/scripts/deploy_odoo.sh")
    cert_hash   = sha256(tls_self_signed_cert.cert[each.key].cert_pem)
  }

  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = each.value.cluster_name
      CLIENT       = local.current_client
      ENV          = each.key
      DOMAIN       = "odoo.${each.key}.${local.current_client}.local"
      # Pass the generated certificate and key instead of minikube client certs
      KUBE_CERT    = tls_self_signed_cert.cert[each.key].cert_pem
      KUBE_KEY     = tls_private_key.key[each.key].private_key_pem
    }

    command = "bash ./scripts/deploy_odoo.sh"
  }
}