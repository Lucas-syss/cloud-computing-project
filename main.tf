terraform {
  required_version = ">= 1.0.0"
  required_providers {
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

provider "null" {}
provider "local" {}
provider "tls" {}

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

resource "null_resource" "minikube_cluster" {
  for_each = { for item in local.deployments : item.id => item }

  triggers = {
    cluster_name = each.value.id
  }

  provisioner "local-exec" {
    
    command = "minikube start -p ${each.value.id} --driver=docker --container-runtime=docker --force --memory 1800 --cpus 2"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "minikube delete -p ${self.triggers.cluster_name}"
  }
}

resource "null_resource" "odoo_deploy" {
  for_each = { for item in local.deployments : item.id => item }

  depends_on = [null_resource.minikube_cluster]

  triggers = {
    cluster_name  = each.value.id
    domain        = each.value.domain
    cert_pem      = tls_self_signed_cert.odoo[each.key].cert_pem
    key_pem       = tls_private_key.odoo[each.key].private_key_pem
    template_hash = sha1(file("templates/odoo-stack.yaml.tmpl"))
  }

  provisioner "local-exec" {
    command = "bash scripts/deploy_odoo.sh '${each.value.id}' '${each.value.client}' '${each.value.env}' '${each.value.domain}' '${base64encode(tls_self_signed_cert.odoo[each.key].cert_pem)}' '${base64encode(tls_private_key.odoo[each.key].private_key_pem)}'"
  }
}

# 4. Update local /etc/hosts
resource "null_resource" "update_hosts" {
  depends_on = [null_resource.odoo_deploy]
  
  triggers = {
    deployments = join(",", [for item in local.deployments : item.domain])
  }

  provisioner "local-exec" {
    command = "bash scripts/update_hosts.sh"
  }
}
