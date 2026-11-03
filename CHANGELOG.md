# Changelog — schematize-terraform

Todas as mudanças relevantes deste pacote, no formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [0.4.0] — 2026-11-03

### Corrigido
- CI de IaC (piso 27): `assets/ci/github-actions-terraform.yml` deixa de usar `pull_request` e `push` em branch; gatilho `workflow_dispatch` + `push: tags [hml-*, v*]`, `concurrency` com `cancel-in-progress: true` (apply com concurrency próprio por ambiente, `false` justificado), `apply-hml`/`apply-prd` só atrás de `environment` com aprovação, nunca em push de branch. Job `alvo` resolve o ambiente pela tag/input sem interpolar no shell.
- Plan revisado = plan aplicado: o apply baixa o artefato do plan da mesma execução (`run_id`), sem recalcular.
- `assets/ci/github-actions-drift.yml`: sem cron por padrão (`workflow_dispatch`); cron fica comentado e exige `# justificativa:`.
- Docs, comandos e DoD (`fluxo.md`, `qualidade.md`, `tf-*`, SKILL, CLAUDE.md, README): "CI no PR" e "trava o merge" viram "trava a promoção"/gate local.

### Adicionado
- `references/fluxo.md` §1.1 "Identidade da IA" (e piso 7): a IA nunca roda `apply`/`destroy`/`state *` local, nem em hml; pede a operação nomeada ao ops; credencial somente leitura.
- `scripts/check-ci-triggers.sh` (cópia herdada da engineering) e regra `ci-gatilho` no `check-tf.sh`: reprova push de branch, `pull_request`, cron sem justificativa e workflow sem concurrency cancel true. Testes vermelho->verde (7 casos novos, incluindo os dois templates).
- Bloco herdado dos pisos 22–29 da `schematize-engineering` em SKILL.md e `assets/CLAUDE.md`.

## [0.3.0] — 2026-10-14
Description reduzida para o orçamento de listagem do catálogo; sem mudança de piso.

### Alterado
- Description encurtada para ≤190 caracteres (catálogo estourou o orçamento de 9000 com 45 skills), mantendo O QUE + gatilho concreto + divisa com as irmãs.
- Ponteiro: segredo que já entrou no git é tratado como vazado, com o passo a passo na `schematize-git` (`references/segredos.md`).

## [0.2.0] — 2026-10-14
Paridade OpenTofu/Terraform. Antes a skill dizia "OpenTofu por default, Terraform por ADR (BUSL)"; a decisão
passou a ser que os dois são cidadãos de primeira classe, escolhidos por projeto com critério objetivo.

### Alterado
- Piso 1 (SKILL, `assets/CLAUDE.md`): sem default e sem ADR obrigatório; **uma** ferramenta por repo, nunca misturar; state em claro vetado nas duas (OpenTofu com `encryption` enforced; Terraform com backend server-side + KMS e acesso restrito).
- `references/ferramenta.md` reescrita: tabela de critérios (licença MPL x BUSL e o que implica, criptografia nativa só no OpenTofu, features exclusivas, registry/providers, HCP Terraform/Stacks, suporte comercial), convenção `*.tofu`/`*.tofutest.hcl` e migração nos dois sentidos.
- Comandos, exemplos e references passam a `$TF` (`tofu` ou `terraform`); `state.md` ganha §4.1 (Terraform: SSE-KMS/CMEK).
- Description e title explicitam "OpenTofu e Terraform" (gatilhos `*.tf`, `*.tofu`, `tofu`, `terraform`, `.terraform.lock.hcl`); nome do pacote e prefixo `tf-` mantidos.
- Esqueleto: `encryption.tofu` por env (o Terraform ignora `*.tofu`) e `kms_key_id` no backend S3; `assets/repo-skeleton-terraform/` traz os locks do registry do Terraform (5 plataformas). Validado com OpenTofu 1.13.1 e Terraform 1.16.5.
- CI e drift de referência parametrizados por `TF_TOOL` (`setup-opentofu` ou `setup-terraform`, ambos pinados por SHA verificado com `gh api`).

### Adicionado
- `check-tf.sh` detecta a ferramenta (lock/registry, `*.tofu`, `*.tofutest.hcl`, bloco `encryption{}`, workflow/`TF_TOOL`, `# tf-tool:`, `TF_GATE_TOOL`) e aplica o ramo certo: `tofu-sem-criptografia`, `tofu-criptografia-sem-enforced`, `terraform-state-sem-kms`, `ferramenta-mista`, `ferramenta-indefinida` (aviso). Reconhece `*.tofu`.
- `check-tf.test.sh`: 48 casos (19 novos, vermelhos plantados nos dois ramos, mista, workflow, waiver).

## [0.1.1] — 2026-10-14
Integração ao catálogo (grafo, skills.json, herdados) e correção do texto de precedência herdado.

### Alterado
- Description reduzida (≤235 chars) para caber no orçamento de listagem de skills (soma ≤8300); mesmo território, fronteiras com as irmãs preservadas.
- Blocos herdados ressincronizados com a `schematize-engineering` v0.27.0 (`tools/sync-herdados.mjs`): orquestração com a regra de imagem (nunca pelo Claude; detecta Codex/Gemini e pergunta ao usuário qual usar, Codex como sugestão) e `schematize overdev delegar` (comando do app) no lugar do falso nome de skill `schematize-overdev`.
- Bloco "Precedência e herança" passa à variante `dominio`: o texto antigo dizia que os comandos `/tf-*` "cobrem só o piso da linguagem", o que é falso para skill de domínio/ferramenta.

## [0.1.0] — 2026-10-14
Primeira versão. A `schematize-infra` trata IaC como princípio agnóstico de ferramenta, mas o
Terraform/OpenTofu tem armadilhas próprias que viram incidente (state local, provider solto,
workspace como "ambiente", segredo no state, apply da máquina do dev) e não tinham dono nem gate.

### Adicionado
- `SKILL.md` com 14 pisos, fronteira explícita com `schematize-infra` e mapa de references.
- `references/`: `ferramenta` (OpenTofu por default por ser MPL, Terraform por ADR por ser BUSL;
  diferenças verificadas: criptografia de state, `enabled`, `-exclude`, `ephemeral`/write-only),
  `estrutura` (por que workspace não separa prd de hml), `state`, `versoes-e-modulos`, `segredos`,
  `fluxo`, `qualidade`, `providers` (Hetzner, Cloudflare v5, GitHub, AWS) e `stack-versoes`.
- `scripts/check-tf.sh` + `check-tf.test.sh`: 13 regras estáticas, sem depender de `tofu`/`terraform`,
  29 casos (vermelhos plantados), waiver `# tf-ok:`.
- `assets/`: esqueleto de repo validado em OpenTofu 1.13.1 e Terraform 1.16.5 (com lock files
  multiplataforma reais e teste de módulo com `mock_provider`), backends de exemplo, `.tflint.hcl`,
  política Rego com teste, workflows de CI e de drift com actions pinadas por SHA.
- Comandos: `tf-help`, `tf-load`, `tf-review`, `tf-plan`, `tf-module`, `tf-drift`, `tf-import`,
  `tf-claude`, `tf-handoff`, `tf-cc`.

### Não verificado
- `plan`/`apply` contra provedor real, backend S3 real, `use_lockfile` em S3-compatível e o
  workflow rodando no GitHub (ver `references/stack-versoes.md`).
