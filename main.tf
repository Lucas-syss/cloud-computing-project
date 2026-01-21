terraform {
  required_version = ">= 1.0.0"
  required_providers {
    minikube = {
      source  = "scott-the-programmer/minikube"
      version = "0.4.4"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

provider "minikube" {
  kubernetes_version = "v1.30.0"
}

provider "null" {}
provider "local" {}
provider "tls" {}

variable "clients" {
  description = "Map of clients and their environments"
  type = map(object({
    environments = list(string)
  }))
  default = {
    "airbnb" = {
      environments = ["dev", "prod"]
    }
    "nike" = {
      environments = ["dev", "qa", "prod"]
    }
    "mcdonalds" = {
      environments = ["dev", "qa", "beta", "prod"]
    }
  }
}

locals {
  deployments = flatten([
    for client_name, client_config in var.clients : [
      for env in client_config.environments : {
        client = client_name
        env    = env
        id     = "${client_name}-${env}"
        domain = "odoo.${env}.${client_name}.local"
      }
    ]
  ])
}

# 1. Generate TLS Certificates for each domain
resource "tls_private_key" "odoo" {
  for_each  = { for item in local.deployments : item.id => item }
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "odoo" {
  for_each        = { for item in local.deployments : item.id => item }
  private_key_pem = tls_private_key.odoo[each.key].private_key_pem

  subject {
    common_name  = each.value.domain
    organization = "Cloud Platform Engineering"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# 2. Provision Minikube Clusters
resource "minikube_cluster" "cluster" {
  for_each = { for item in local.deployments : item.id => item }

  driver       = "docker"
  cluster_name = each.value.id
  addons = [
    "ingress",
    "default-storageclass",
    "storage-provisioner"
  ]
  
  # Resource limits as per standard practice, configurable if needed but hardcoded for now
  memory = "2048mb"
  cpus   = 2
}

# 3. Deploy Odoo Application (Using shell script wrapper for kubectl)
# We use this because the kubernetes provider cannot be dynamic in a for_each
resource "null_resource" "odoo_deploy" {
  for_each = { for item in local.deployments : item.id => item }

  depends_on = [minikube_cluster.cluster]

  triggers = {
    cluster_name  = each.value.id
    domain        = each.value.domain
    cert_pem      = tls_self_signed_cert.odoo[each.key].cert_pem
    key_pem       = tls_private_key.odoo[each.key].private_key_pem
    template_hash = sha1(file("${path.module}/templates/odoo-stack.yaml.tmpl"))
    script_hash   = sha1(file("${path.module}/scripts/deploy_odoo.sh"))
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/deploy_odoo.sh '${each.value.id}' '${each.value.client}' '${each.value.env}' '${each.value.domain}' '${base64encode(tls_self_signed_cert.odoo[each.key].cert_pem)}' '${base64encode(tls_private_key.odoo[each.key].private_key_pem)}'"
  }
}

# 4. Update local /etc/hosts for validation
resource "null_resource" "update_hosts" {
  depends_on = [minikube_cluster.cluster] # Needs IPs
  
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/update_hosts.sh"
  }
}
