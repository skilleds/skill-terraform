# Módulo filho: declara o que precisa (piso), NUNCA configura provider (quem configura é a raiz).
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.50.0, < 2.0.0"
    }
  }
}
