# Anexo volátil — versões e ferramental (Terraform / OpenTofu)

> Parte da skill **schematize-terraform**. **Fonte volátil:** número de versão, nome de recurso de
> provider, suporte de recurso por versão e preço mudam. O corpo normativo diz **princípio**; o
> número mora aqui, com data e fonte.
>
> **Verificado em: 2026-10-14.** Cadência: revisão trimestral e antes de cada release da skill.
> Método: API de releases do GitHub (`gh api repos/<org>/<repo>/releases/latest`), CHANGELOG de cada
> linha menor lido no repositório oficial, docs dos providers no repositório do provider, e execução
> real dos exemplos (abaixo).

## CLIs

| Ferramenta | Corrente (2026-10-14) | Fonte | Nota |
|---|---|---|---|
| **OpenTofu** | **1.13.1** (2026-10-01) | `opentofu/opentofu` releases | licença **MPL-2.0** (API do GitHub). Linhas 1.11.x e 1.13.x têm janela de suporte declarada no CHANGELOG (1.11 até 2026-08-01; 1.13 até 2027-08-01) |
| **Terraform** | **1.16.5** (2026-10-02); 1.17.0-rc1 em pré-release | `hashicorp/terraform` releases | licença **BUSL-1.1** desde a 1.6 (a API do GitHub devolve "NOASSERTION" por ser licença própria; arquivo `LICENSE` do repo abre com o texto da BUSL) |
| TFLint | 0.64.0 (2026-07-17) | `terraform-linters/tflint` | ruleset `terraform` empacotada 0.15.0; `tflint-ruleset-aws` 0.49.0 |
| Checkov | 3.3.29 (2026-10-13) | `bridgecrewio/checkov` | mantido pela Palo Alto Networks (Prisma Cloud); CLI gratuita <!-- reverificar --> |
| Trivy | 0.75.0 (2026-10-01) | `aquasecurity/trivy` | `trivy config` absorveu o `tfsec` <!-- reverificar data da incorporação --> |
| conftest | 0.71.1 | `open-policy-agent/conftest` | OPA 1.21.1 embutido |
| Infracost | 0.10.46 | `infracost/infracost` | cobertura de provedores: <!-- reverificar --> |
| Terratest | módulo `modules/core/v2.0.0` | `gruntwork-io/terratest` | opcional |

Plataforma (2026-10-14): o HashiConf 2025 anunciou **Stacks em GA** no HCP Terraform (fonte: blog da
HashiCorp; arquivos `*.tfcomponent.hcl`). Fim do free tier do HCP em 2026-03 aparece em comparativos de
terceiros: <!-- reverificar -->. `terraform query` e `actions` constam no CHANGELOG do Terraform 1.14+.

Contexto institucional (não verificado nesta rodada): a HashiCorp foi adquirida pela IBM, e o
OpenTofu é projeto da Linux Foundation, com relato de ingresso na CNCF em 2025.
<!-- reverificar: datas e estágio na CNCF -->

## Recursos de linguagem — desde qual versão (fonte: CHANGELOG de cada linha)

| Recurso | Terraform | OpenTofu |
|---|---|---|
| Bloco `import` | 1.5 | 1.6 |
| `terraform test` / `tofu test` | 1.6 | 1.6 |
| `mock_provider` | 1.7 | 1.7 |
| Bloco `removed` | 1.7 | 1.7 |
| **Criptografia de state/plan** | **não existe** | **1.7** (provedores de chave: `aws_kms`, `gcp_kms`, `openbao`, `pbkdf2`, programa externo desde 1.10) |
| Variáveis/locals em `backend` e em `source` de módulo | não | 1.8 (sem valor sensível) |
| `-exclude` | não | 1.9 |
| `-exclude-file`, `-target-file` | não | 1.10 |
| Backend S3 `use_lockfile` | 1.10 (experimental), GA na 1.11 | 1.10 |
| `dynamodb_table` do backend S3 | deprecado desde a 1.11 | deprecado |
| `ephemeral` (variável, saída, recurso) | 1.10 | 1.11 |
| Argumentos **write-only** (`*_wo`) | 1.11 | 1.11 |
| `lifecycle { enabled = ... }` | não | 1.11 |
| `deprecated` em variável/saída | <!-- reverificar --> | 1.10 |
| Bloco `actions` | 1.14 | <!-- reverificar --> |
| `-lint` (experimental) | não | 1.13 |

## Providers (últimas releases em 2026-10-14)

| Provider | Versão | Observação |
|---|---|---|
| `hetznercloud/hcloud` | 1.70.0 | `hcloud_zone`/`hcloud_zone_record` (DNS) e `hcloud_storage_box*` existem na doc atual |
| `cloudflare/cloudflare` | 5.28.0 | `cloudflare_dns_record` (era `cloudflare_record` na v4); `ttl` obrigatório |
| `integrations/github` | 6.13.0 | `vulnerability_alerts` em `github_repository` está deprecado: usar `github_repository_vulnerability_alerts` |
| `hashicorp/aws` | 6.68.0 | `aws_db_instance.password_wo` + `password_wo_version`; recurso efêmero `aws_secretsmanager_secret_version` |
| `hashicorp/vault` | 5.12.0 | tem recursos efêmeros (ex.: `vault_database_secret`) |

## GitHub Actions usadas nos assets (SHA verificado com `gh api` em 2026-10-14)

| Action | Tag | SHA |
|---|---|---|
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/upload-artifact` | v7.0.2 | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` |
| `actions/download-artifact` | v8.0.2 | `9000827ccba6bdab643e8b6fd33ac0654aef8333` |
| `opentofu/setup-opentofu` | v2.0.2 | `a1320f892987e89d278cc92dc5adc984fb93aca4` |
| `terraform-linters/setup-tflint` | v6.3.2 | `6ffdbaa3be476b3431f7275c26966ef32ff60337` |
| `hashicorp/setup-terraform` | v4.0.1 | `dfe3c3f87815947d99a8997f908cb6525fc44e9e` |

Os dois `setup-*` entram nos workflows de `assets/ci/` sob `if: env.TF_TOOL == ...` (paridade).

Tag anotada foi desreferenciada até o commit. Renovação: refaça `gh api repos/<r>/git/ref/tags/<tag>`.

## O que foi EXECUTADO para escrever esta skill (2026-10-14, Linux amd64)

- OpenTofu 1.13.1 e Terraform 1.16.5 baixados com checksum conferido (SHA256SUMS oficial).
- `tofu init -backend=false` + `tofu validate` + `tofu fmt -check` no esqueleto `assets/repo-skeleton/`
  (hml e prd) e `providers lock` multiplataforma (5 plataformas) gerando os `.terraform.lock.hcl` reais.
- `tofu test` e `terraform test` no módulo `servidor` com `mock_provider`: 3 testes passam nas duas CLIs.
- `tflint` 0.64.0 com `assets/lint/.tflint.hcl`: esqueleto limpo; arquivo ruim acusa.
- `checkov` 3.3.29 no esqueleto: sem falhas.
- Criptografia do OpenTofu: state **e** plan saíram cifrados (provedor `pbkdf2`, `enforced = true`;
  `grep` do valor em claro devolveu 0). Provedor `aws_kms`: apenas **validado** (sem conta AWS).
- `conftest verify` em `assets/policy` (3 testes) e `conftest test` em plan JSON fabricado.
- **Paridade (2026-10-14)**: esqueleto validado com as DUAS CLIs: OpenTofu 1.13.1 (`init -backend=false`,
  `validate`, `fmt -check`, `test` com 3 passes; com `encryption.tofu`) e Terraform 1.16.5 (esqueleto sem
  os `*.tofu`, lock regerado em `assets/repo-skeleton-terraform/` com 5 plataformas, `validate`, `fmt -check`,
  `test` com 3 passes). `check-tf.sh` passa nos dois ramos; 48 casos em `check-tf.test.sh`.
  Workflows de `assets/ci/` parseados como YAML e o gate detecta `TF_TOOL` nos dois valores.
- Exemplos de `providers.md` (hcloud, cloudflare, github, aws) e de `segredos.md` (`ephemeral` +
  `password_wo`) passam em `tofu validate`; o de segredos também em `terraform validate`.

**NÃO verificado:** `plan`/`apply` contra provedor real (sem credencial); backend S3 real e seu
`use_lockfile`; S3-compatível (Hetzner/R2) com `use_lockfile`; o workflow de CI rodando no GitHub
(só o YAML parseado e as actions conferidas); Infracost; Trivy; Terratest.
