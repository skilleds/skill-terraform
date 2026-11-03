# Credencial do provider: variável de ambiente HCLOUD_TOKEN (secret do GitHub Environment "hml").
# Nada de token em variável, tfvars ou código.
provider "hcloud" {}

locals {
  labels = {
    owner      = "time-plataforma"
    project    = "demo"
    managed_by = "opentofu"
  }
}

module "app" {
  source = "../../modules/servidor"

  nome             = "app-hml"
  ambiente         = "hml"
  ssh_key_ids      = var.ssh_key_ids
  ssh_permitido_de = var.ssh_permitido_de
  protegido        = false
  labels           = local.labels
}
