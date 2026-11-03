# Qualidade: formato, estática, teste, política, custo, tags

> `$TF` = o binário do repo: `tofu` ou `terraform` (uma só por repo). Tudo abaixo vale para os dois.

> Cada degrau pega uma classe diferente de erro. Nenhum substitui a leitura do `plan`.

## 1. Os degraus (ordem; por commit, local; no CI remoto só na promoção)

| # | Ferramenta | Pega | Precisa de credencial? | Trava a promoção? |
|---|---|---|---|---|
| 1 | `$TF fmt -check -recursive` | estilo | não | sim |
| 2 | `$TF init -backend=false && $TF validate` | sintaxe, tipos, referências | não | sim |
| 3 | `scripts/check-tf.sh` (esta skill) | backend local, provider solto, lock, segredo, state versionado, crítico sem `prevent_destroy` | não | sim |
| 4 | `tflint` | convenção, variável sem descrição, módulo sem pin, regras do provider | não | sim |
| 5 | `checkov` / `trivy config` | má configuração de segurança (bucket público, SG aberto, sem criptografia) | não | sim (HIGH/CRITICAL) |
| 6 | `$TF test` | contrato do módulo | não (mock) | sim |
| 7 | `plan` + `conftest` | política da casa sobre o plan real | leitura | sim |
| 8 | `infracost` (opcional) | custo | leitura | aviso |

## 2. fmt, validate e tflint

- `fmt` sem opinião: o formato é o da ferramenta. Pre-commit local e `-check` no CI.
- `validate` roda **sem backend e sem credencial** (`init -backend=false`), então roda sem segredo.
- `tflint` com a config da casa: `assets/lint/.tflint.hcl` (naming snake_case, variável/saída
  documentada, módulo com pin, `required_version`, declarações não usadas). Plugin do provider
  (AWS, etc.) fixado por versão. Com `--recursive`, passe `--config` com **caminho absoluto**.
- `terraform-docs` gera a tabela de entradas/saídas do README do módulo (CI confere que não divergiu).

## 3. Testes

### 3.1 Nativo (`tofu test` / `terraform test`)
Arquivo `tests/*.tftest.hcl` ao lado do módulo. Três usos:

- **`command = plan` + `assert`**: valida lógica (locals, labels, validações) sem criar nada.
- **`expect_failures`**: prova que a `validation` **rejeita** o que deve. É o "vermelho primeiro" do módulo.
- Arquivos: `*.tftest.hcl` roda nas duas ferramentas; `*.tofutest.hcl` é só do OpenTofu (o Terraform
  ignora) — use para teste que exercita recurso exclusivo.
- **`mock_provider`**: roda sem credencial nem rede (Terraform 1.7+, OpenTofu 1.7+). Cuidado: o
  mock inventa valores (ids aleatórios em string) — use `mock_resource`/`defaults` quando o tipo importa.
- **`command = apply`** (real) só em conta/projeto de teste descartável, com `terraform test`
  limpando ao fim. Custa dinheiro e tempo: reserve para módulo crítico.

Exemplo validado nesta skill: `assets/repo-skeleton/modules/servidor/tests/servidor.tftest.hcl`
(3 testes passam em OpenTofu 1.13.1 e em Terraform 1.16.5).

### 3.2 Terratest (opcional)
Biblioteca Go (`gruntwork-io/terratest`) para testes de integração que sobem infra real e
batem nela (HTTP, SSH). Use quando o teste nativo não alcança (verificar comportamento da
infra, não só do plano). Regras: conta isolada, nome com sufixo aleatório, `defer destroy`,
timeout, e **nunca** em conta de prd. O padrão da casa para Go se aplica (`schematize-go`).

### 3.3 Pirâmide
Muito `validate`/estático e teste de módulo com mock; pouco teste real e caro. Disciplina geral:
`schematize-qa`.

## 4. Segurança estática: checkov e trivy

- **checkov** (`checkov -d . --framework terraform`): amplo, lê HCL e o plan JSON. Fixe a versão
  no CI; baseline de exceções em arquivo, com motivo (`#checkov:skip=CKV_...:motivo`).
- **trivy config** (`trivy config .`): substituiu o `tfsec` (descontinuado e incorporado ao
  Trivy). Útil se a casa já usa Trivy para imagens (`schematize-docker → scan`).
- Use **um** como gate e o outro, se quiser, como informativo. Exceção sem motivo escrito é dívida.
- Achado de segurança que depende de contexto (SG aberto de propósito num LB público) vira
  `skip` **com justificativa**, revisada no commit.

## 5. Política como código (OPA/conftest)

O que o linter não sabe é o que **a casa** exige: tags obrigatórias, regiões permitidas,
tipos proibidos, "destroy de recurso crítico exige aprovação nomeada". Rego sobre o JSON do plan:

```bash
$TF plan -out=plano.tfplan && $TF show -json plano.tfplan > plano.json
conftest test --policy policy/ plano.json
```

`assets/policy/plano.rego` (+ `plano_test.rego`, rodado com `conftest verify`) cobre: marcas
`owner/project/managed_by/env` em tudo que aceita `labels`/`tags` e bloqueio de destroy/replace
em tipos críticos. **Teste a política** (`conftest verify`) como se testa código: política
sem teste é regra que ninguém sabe se funciona.

## 6. Custo (opcional)

`infracost breakdown --path=. ` / `infracost diff` na promoção comenta o delta mensal. Defina
limiar: acima de X por mês a mudança exige aprovação financeira. Limite: só cobre provedores
que o Infracost precifica (AWS/Azure/GCP; Hetzner e Cloudflare não por padrão) <!-- reverificar -->;
para os demais, estime por tabela do provedor no commit.

## 7. Tags e labels obrigatórias

Conjunto mínimo: `env` (hml/prd), `owner` (time/pessoa), `project`, `managed_by` (`opentofu`/
`terraform`). Aplicação:
- **AWS**: `provider "aws" { default_tags { tags = {...} } }` (a raiz cobre tudo).
- **Hetzner**: `labels` por recurso (módulo mescla `var.labels` + `env`).
- **Cloudflare**: sem tags na maioria dos recursos; use `comment` onde houver.
- Validação no módulo (`validation` exige as chaves) **e** na política do plan (rede de segurança).
Sem tag, não há dono; sem dono, não há quem responda no incidente nem quem pague a conta.

## 8. Documentação

ADR (quando a decisão custou debate) para: escolha OpenTofu vs Terraform, backend e chave de criptografia, divisão de stacks,
adoção de Terragrunt. Runbook para: bootstrap do state, restauro de state, rotação de chave,
break-glass (`schematize-docs`).
