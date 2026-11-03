locals {
  labels = merge(var.labels, { env = var.ambiente })
}

resource "hcloud_firewall" "this" {
  name   = "${var.nome}-fw"
  labels = local.labels

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_permitido_de
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "this" {
  name        = var.nome
  server_type = var.tipo
  image       = "debian-13"
  location    = var.localizacao
  ssh_keys    = var.ssh_key_ids
  labels      = local.labels

  firewall_ids      = [hcloud_firewall.this.id]
  delete_protection = var.protegido
  # rebuild_protection tem de acompanhar delete_protection (exigência do provider)
  rebuild_protection = var.protegido

  lifecycle {
    # apagar/recriar servidor de prd é decisão humana explícita, nunca efeito colateral de um plan
    prevent_destroy = true
  }
}
