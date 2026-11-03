# Qual ferramenta: OpenTofu e Terraform, em paridade

> A casa escreve IaC em HCL e roda com **OpenTofu** (`tofu`) **ou** **Terraform** (`terraform`).
> Os dois são cidadãos de primeira classe: **sem default e sem ADR obrigatório para nenhum**. A
> escolha é **por projeto/repo**, uma decisão normal registrada no README/ADR do projeto, com os
> critérios objetivos da §2. Versões e datas ficam no anexo volátil `stack-versoes.md`.

## 1. A política

1. **Escolha por repo, com critério objetivo (§2).** Registre no README do repo (e em ADR quando a
   decisão custou debate: `schematize-docs → adr`): a ferramenta, a versão, os critérios que
   pesaram. Não há "ferramenta da casa": há a do repo.
2. **UMA ferramenta por repositório; nunca misturar.** O `.terraform.lock.hcl` carrega o *registry*
   de origem de cada provider (`registry.opentofu.org/...` vs `registry.terraform.io/...`): trocar de
   ferramenta no meio muda o lock, e dois lados no mesmo repo é o início do incidente. O gate
   `check-tf.sh` detecta a ferramenta (lock/registry, `*.tofu`/`*.tofutest.hcl`, bloco
   `encryption {}`, workflow, `TF_TOOL`, marcador `# tf-tool: tofu|terraform`) e reprova sinais dos
   dois lados (`ferramenta-mista`). Migração em andamento: waiver `# tf-ok: ferramenta-mista <motivo>`.
3. **State em claro é proibido nas duas** (piso 3 da SKILL):
   - **OpenTofu**: `terraform { encryption { ... } }` com `enforced = true` em `state` (e `plan`),
     chave em KMS/OpenBao ou `TF_ENCRYPTION` do cofre do CI. Soma-se, não substitui, a criptografia
     do backend. Gate: `tofu-sem-criptografia`, `tofu-criptografia-sem-enforced`.
   - **Terraform**: não cifra no cliente. Exige **backend com criptografia server-side + KMS** (S3:
     `encrypt = true` + `kms_key_id`; GCS: `kms_encryption_key`), bucket versionado, acesso mínimo ao
     state e à chave, artefato de plan com retenção curta em repo privado. HCP Terraform
     (`cloud {}`) cifra o state do lado dele. Gate: `terraform-state-sem-kms`.
4. **Código portável por construção.** Escreva o subconjunto comum de HCL sempre que o recurso
   exclusivo não pagar o custo de prender o repo a uma ferramenta. O que é exclusivo de um lado
   (§3) entra **declarado**: comentário, `required_version` coerente e, num módulo reutilizável,
   aviso no README. Convenção de arquivo: código exclusivo do OpenTofu vai em `*.tofu` (o Terraform
   **ignora** `*.tofu`) e teste exclusivo em `*.tofutest.hcl` — o esqueleto usa isso para a
   criptografia (`encryption.tofu`).
5. **Comandos nesta skill**: aparecem como `tofu` / `terraform` lado a lado ou como `$TF` (o
   binário do repo: `TF=tofu` ou `TF=terraform`). Todo exemplo, gate e workflow vale para os dois;
   onde só um lado tem o recurso, o texto diz.

## 2. Critérios de escolha (tabela de decisão)

| Critério | OpenTofu | Terraform | O que decide |
|---|---|---|---|
| **Licença da CLI** | MPL-2.0 (open source, OSI) | BUSL-1.1 desde a 1.6 (a 1.5.x foi a última MPL) | Quem vende plataforma/PaaS/ferramenta de infra que possa **concorrer com a HashiCorp/IBM** precisa de parecer jurídico para a BUSL; uso interno e consultoria de IaC em geral não esbarram. Exigência de licença OSI (contrato, governo, redistribuição da CLI) pende para OpenTofu |
| **Criptografia de state/plan** | **nativa no cliente** (1.7+): vale para qualquer backend | **não existe**; só server-side do backend + KMS | Backend sem KMS decente (S3-compatível, MinIO), ameaça de bucket exposto ou de plan como artefato favorecem OpenTofu; com S3+KMS e acesso restrito o Terraform atende ao piso |
| **Features exclusivas** | `lifecycle { enabled }`, `-exclude`/`-exclude-file`, variáveis em `backend`/`source`, `for_each` em `provider`, `-lint` (experimental) | `actions` (1.14+), `terraform query`/`list` (1.14+, evolução), integração nativa com HCP | Conte só o que o repo **vai usar**; recurso exclusivo prende o repo (§1.4) |
| **Registry e providers** | `registry.opentofu.org` (mirror dos providers públicos); providers da comunidade e dos grandes funcionam nos dois | `registry.terraform.io`; provider/módulo **privado ou parceiro** pode ter suporte oficial só aqui | Verifique cada provider e módulo do repo nos dois registries antes de decidir; o lock fixa o registry |
| **Plataforma gerenciada** | sem SaaS oficial; roda em CI próprio ou em plataformas de terceiros (Atlantis, Spacelift, env0, Scalr etc.) | **HCP Terraform / Terraform Enterprise**: runs remotos, policy (Sentinel), Stacks (GA no HCP) | Cliente que já opera HCP/TFE e a migração não paga o custo -> Terraform. Sem plataforma gerenciada, o CI de referência (`assets/ci/`) cobre os dois |
| **Suporte comercial** | de empresas terceiras e consultorias (Linux Foundation hospeda o projeto) | HashiCorp/IBM, com SLA em contrato | Exigência de fornecedor único de suporte com SLA -> Terraform; suporte por terceiros aceito -> qualquer |
| **Ecossistema de ferramentas** | tflint, checkov, trivy, conftest, infracost, terratest funcionam nos dois | idem | Não decide: o ecossistema é compartilhado |
| **Exigência contratual / do cliente** | idem | idem | Contrato que nomeia a ferramenta decide por cima do resto |

"É mais barato" e "tem mais comunidade" **não são critérios**: os dois são grátis para rodar e o
ecossistema de providers/módulos é compartilhado.

## 3. Diferenças que mudam o desenho (verificado — fontes em `stack-versoes.md`)

| Tema | OpenTofu | Terraform |
|---|---|---|
| Licença da CLI | MPL-2.0 | BUSL-1.1 |
| **State/plan encryption** | **sim**, `terraform { encryption { ... } }` (1.7+) | **não** (só criptografia do backend/servidor) |
| Valores efêmeros (`ephemeral` var/output/resource) | sim (1.11+) | sim (1.10+) |
| Argumentos **write-only** (`*_wo`) | sim (1.11+) | sim (1.11+) |
| `enabled` em `lifecycle` (0 ou 1 instância, no lugar de `count = x ? 1 : 0`) | **sim** (1.11+) | não |
| `-exclude`/`-exclude-file` no plan/apply | sim (1.9+/1.10+) | não |
| Variáveis/locals em `backend` e em `source` de módulo | sim (1.8+) | não |
| Bloco `import`, `moved`, `removed`, `test`, `mock_provider` | sim | sim |
| `actions` (bloco top-level de ações do provider) | não <!-- reverificar --> | sim (1.14+) |
| Lint integrado | `-lint` (1.13+, experimental) | não |
| Arquivos exclusivos | `*.tofu`, `*.tofutest.hcl` | `*.tfcomponent.hcl`/Stacks (HCP) <!-- reverificar --> |

Regra de uso: **nunca** dependa de recurso exclusivo sem declarar. Um módulo reutilizável que usa
`enabled` ou `encryption` só roda em OpenTofu e deve dizer isso no README e em `required_version`.

## 4. Como o gate trata cada ramo

| Detectado | Regras extras de state |
|---|---|
| OpenTofu | raiz com backend remoto exige `encryption {}` com `enforced = true` |
| Terraform | raiz com backend `s3` exige `encrypt = true` **e** `kms_key_id`; `gcs` exige `kms_encryption_key`; tipo desconhecido gera aviso; S3-compatível sem KMS exige waiver `# tf-ok: terraform-state-sem-kms <motivo>` |
| Nenhum sinal | aviso `ferramenta-indefinida`; declare com `# tf-tool: tofu|terraform` ou `TF_GATE_TOOL` |
| Os dois | erro `ferramenta-mista` |

As demais regras (backend, pin, lock multiplataforma, segredo, `prevent_destroy`...) são as mesmas.

## 5. Migração entre as duas (decisão de projeto, não de política)

- **Terraform ≤ 1.5.x <-> OpenTofu**: troca direta (state compatível). Rode `$TF init`, confira o
  `plan` vazio, regere o lock (`$TF providers lock` multiplataforma, 5 plataformas) e commite.
- **Terraform ≥ 1.6 -> OpenTofu**: depende do que o state já usa; **teste em cópia** do state
  (`plan` sem diff) antes de trocar o CI. A documentação oficial de migração do OpenTofu manda.
  <!-- reverificar: matriz de compatibilidade por versão do Terraform -->
- **OpenTofu -> Terraform**: o state criptografado pelo OpenTofu **não** abre no Terraform:
  desligue a criptografia numa migração planejada (e ligue SSE-KMS no backend) antes.
- Em qualquer sentido: um PR só, que troca lock, `required_version`, workflow (`TF_TOOL`), arquivos
  `*.tofu` e o README, e remove os sinais da outra ferramenta.
