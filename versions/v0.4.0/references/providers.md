# Providers da casa: exemplos curtos

> Receitas mínimas e corretas. Versões e nomes de recurso mudam (o provider Cloudflare renomeou
> recursos na v5): confira a doc do provider na versão fixada. Datas em `stack-versoes.md`.

## 1. Hetzner Cloud (`hetznercloud/hcloud`) — VPS

```hcl
terraform {
  required_providers {
    hcloud = { source = "hetznercloud/hcloud", version = "~> 1.70" }
  }
}
provider "hcloud" {}   # token: HCLOUD_TOKEN (secret do Environment). Nunca token em código.

resource "hcloud_ssh_key" "deploy" {
  name       = "deploy-${var.ambiente}"
  public_key = file("${path.module}/chaves/deploy.pub")   # chave PÚBLICA pode ir ao git
}

resource "hcloud_firewall" "web" {
  name = "web-${var.ambiente}"
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "app" {
  name               = "app-${var.ambiente}"
  server_type        = "cx22"
  image              = "debian-13"
  location           = "nbg1"
  ssh_keys           = [hcloud_ssh_key.deploy.id]
  firewall_ids       = [hcloud_firewall.web.id]
  delete_protection  = var.ambiente == "prd"
  rebuild_protection = var.ambiente == "prd"   # tem de acompanhar delete_protection
  labels             = { env = var.ambiente, owner = "plataforma", project = "demo", managed_by = "opentofu" }

  lifecycle {
    prevent_destroy = true
  }
}
```
Notas: `delete_protection` é a trava **do provedor**, além do `prevent_destroy` do Terraform.
Volume com dado: `hcloud_volume` com `prevent_destroy` + `delete_protection`. `user_data`
(cloud-init) fica no state: **sem segredo nele**. Esqueleto completo e validado: `assets/repo-skeleton/`.
Object Storage da Hetzner serve de backend S3-compatível (`state.md` §2).

## 2. Cloudflare (`cloudflare/cloudflare`, v5+) — DNS e borda

```hcl
terraform {
  required_providers {
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 5.28" }
  }
}
provider "cloudflare" {}   # token: CLOUDFLARE_API_TOKEN, escopo mínimo (Zone:DNS:Edit na zona)

resource "cloudflare_dns_record" "app" {
  zone_id = var.zona_id
  name    = "app.${var.dominio}"
  type    = "A"
  content = hcloud_server.app.ipv4_address
  ttl     = 1        # 1 = automático; obrigatório na v5
  proxied = true
  comment = "managed_by=opentofu env=${var.ambiente}"
}
```
Notas: na v5 `cloudflare_record` (v4) virou **`cloudflare_dns_record`** e `value` virou
`content`. Atualizar de v4 para v5 é migração, não bump: leia o guia de upgrade do provider e
use `moved`/`import`. Token **por zona e por ambiente**. DNS de teste em rota nula (null MX, SPF
`-all`, DMARC `reject`): `schematize-infra → references/iac-efeitos-externos.md` §7.

## 3. GitHub (`integrations/github`) — repos como código

```hcl
terraform {
  required_providers {
    github = { source = "integrations/github", version = "~> 6.13" }
  }
}
provider "github" { owner = "minha-org" }   # token: GITHUB_TOKEN (GitHub App > PAT; escopo mínimo)

resource "github_repository" "servico" {
  name                   = "servico-x"
  visibility             = "private"
  delete_branch_on_merge = true

  lifecycle {
    prevent_destroy = true
  }
}

# vulnerability_alerts dentro de github_repository está deprecado: recurso próprio
resource "github_repository_vulnerability_alerts" "servico" {
  repository = github_repository.servico.name
  enabled    = true
}

resource "github_branch_protection" "main" {
  repository_id           = github_repository.servico.node_id
  pattern                 = "main"
  enforce_admins          = true
  required_linear_history = true

  required_status_checks {
    strict   = true
    contexts = ["qualidade"]
  }

  required_pull_request_reviews {
    required_approving_review_count = 1
  }
}
```
Notas: prefira **GitHub App** a PAT. O repositório que guarda a IaC e seus Environments
(`prd` com revisores) também pode ser gerido assim, mas o **bootstrap** é manual (ovo e galinha).
Segredos de Actions (`github_actions_secret`) gravam o valor no **state**: prefira OIDC; se
inevitável, state cifrado.

## 4. AWS (`hashicorp/aws`) — genérico

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.68" }
  }
}
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = { env = var.ambiente, owner = "plataforma", project = "demo", managed_by = "opentofu" }
  }
  # credencial: OIDC no CI (role por ambiente); no laptop, SSO. Nunca access_key no código.
}

resource "aws_s3_bucket" "dados" {
  bucket = "acme-dados-${var.ambiente}"

  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_s3_bucket_versioning" "dados" {
  bucket = aws_s3_bucket.dados.id

  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_public_access_block" "dados" {
  bucket                  = aws_s3_bucket.dados.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```
Notas: duas contas (hml/prd) com `assume_role` por ambiente; `default_tags` cobre a política de
tags; `aws_db_instance` com `password_wo` + `ephemeral` (`segredos.md` §3); SG com `0.0.0.0/0`
em porta de admin é achado do checkov.

## 5. O que vale para todos

1. Credencial do provider por **variável de ambiente** do Environment, nunca no código.
2. `prevent_destroy` + proteção do provedor em tudo que tem dado.
3. Nome, tags e labels padronizados (`qualidade.md` §7).
4. Provider com `version = "~>"` na raiz e lock commitado (`versoes-e-modulos.md` §1).
