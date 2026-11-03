# terraform test / tofu test — sem credencial: provider mockado.
mock_provider "hcloud" {
  # o mock gera id aleatório em string; firewall_ids exige número
  mock_resource "hcloud_firewall" {
    defaults = {
      id = "1"
    }
  }
}

variables {
  nome             = "app-teste"
  ambiente         = "hml"
  ssh_key_ids      = [1]
  ssh_permitido_de = ["203.0.113.0/24"]
  labels           = { owner = "time-plataforma", project = "demo", managed_by = "opentofu" }
}

run "plano_valido" {
  command = plan

  assert {
    condition     = hcloud_server.this.labels["env"] == "hml"
    error_message = "label env deve refletir o ambiente"
  }
}

run "ssh_aberto_em_prd_e_rejeitado" {
  command = plan

  variables {
    ambiente         = "prd"
    ssh_permitido_de = ["0.0.0.0/0"]
  }

  expect_failures = [var.ssh_permitido_de]
}

run "label_obrigatoria_ausente_e_rejeitada" {
  command = plan

  variables {
    labels = { owner = "x" }
  }

  expect_failures = [var.labels]
}
