---
name: schematize-terraform
metadata:
  version: 0.3.0
description: >-
  IaC com OpenTofu e Terraform em paridade: state cifrado, pins, módulos, plan->apply gated, drift. Use ao tocar *.tf, *.tofu ou .terraform.lock.hcl. Gate check-tf.sh.
---
<!-- cross-skill: isolamento.md, iac.md, iac-efeitos-externos.md, resiliencia.md, segredos.md -> schematize-infra -->

# IaC com OpenTofu e Terraform (schematize-terraform)

Disciplina normativa para **infraestrutura declarada em HCL**, com **OpenTofu e Terraform em
paridade** (cada repo escolhe uma; o nome da skill é histórico). A tese: **o state é a memória da
infra e o `plan` é o contrato** — quem aplica sem ler o plan, ou guarda o state onde qualquer um
lê, ou deixa o ambiente de produção a um `workspace select` de distância do de teste, está a um
comando do incidente. Esta skill é a especialista de IaC; a `schematize-infra` é a visão de
plataforma.

**Versão:** skill `schematize-terraform` v0.3.0. Changelog em `CHANGELOG.md`.

## Precedência e herança (leia antes de divergir)

<!-- herdado:engineering/precedencia:dominio intro="Esta skill é o recorte **IaC declarativa (HCL: OpenTofu/Terraform)** das linguagens **sancionadas fora do rol de backend** (`schematize-engineering` → `references/linguagens.md` §2.2): **ferramenta** — infraestrutura como código, nunca serviço de produto." cmd="tf" -->Esta skill é o recorte **IaC declarativa (HCL: OpenTofu/Terraform)** das linguagens **sancionadas fora do rol de backend** (`schematize-engineering` → `references/linguagens.md` §2.2): **ferramenta** — infraestrutura como código, nunca serviço de produto.

1. **Onde esta skill divergir da base, a BASE MANDA.** Aqui mora a especialização do domínio ou da
   ferramenta — o como, o padrão, o gate. Divergência de *piso* é defeito desta skill, não variante local.
2. **O que não está repetido aqui é HERDADO, não dispensado.** Esta skill herda os pisos da base e
   os comandos dela cobrem o **domínio**, não o piso geral. Valem integralmente, sem cópia local:
   - **§28 Archive** — `<projeto>/<projeto>_archive/` é **repositório git próprio, PRIVADO e
     obrigatório**, criticidade 0 (`schematize-archive`).
   - **§35 Definition of Done** e a lista de anti-padrões (citada por **título**, nunca por número).
   - **§39 Índice/MAPA** — enumeração exaustiva (uma entrada por unidade chamável, `M == N`) e grafo
     com arestas em ASCII (`A -> B`), nunca a seta unicode.
   - **IAM** (`schematize-engineering` → `references/iam.md`): identidade ≠ email, ≥2 fatores, ReBAC
     multi-tenant, argon2id-only para senha nova, sessão longa e logout irreversível.
   - **Efeito externo** nunca sai de não-produção (`schematize-engineering` →
     `references/efeitos-externos.md`).
   - **Orquestração** (`schematize-engineering` → `references/orquestracao.md` §9): o principal não
     desenvolve (é Claude Opus); executor mais barato que resolve — `haiku`/`sonnet` → Codex Terra → Cursor → `opus` só após falha; visual direto ao Codex; imagem nunca pelo Claude: detecta Codex/Gemini e pergunta ao usuário qual usar (Codex é a sugestão, não automática), nunca API paga.
3. **QA, ops, IAM e índice não têm comando próprio aqui:** vêm da base `/eng-*`. Para trabalho
   contínuo use `/eng-overdev`; para planejar `/eng-plan`; para varrer a base `/eng-scan`; para
   revisão geral `/eng-review` (e `/eng-ops`, `/eng-iam`, `/eng-index`). Os comandos
   `/tf-*` cobrem o domínio desta skill; o piso geral é o da base.<!-- /herdado -->

## Fronteira com as outras skills

| Assunto | Dono | Ponteiro |
|---|---|---|
| Isolamento por serviço, deploy, DR, rede/TLS, observabilidade, ops como interface única | `schematize-infra` | `schematize-infra → references/isolamento.md`, `entrega.md`, `resiliencia.md` |
| Princípios de IaC agnósticos de ferramenta (declarativa, idempotente, revisável, GitOps, artefato imutável) | `schematize-infra` | `schematize-infra → references/iac.md` |
| Efeito externo fora de prd como código (DNS de teste em rota nula, egress SMTP) | `schematize-infra` | `schematize-infra → references/iac-efeitos-externos.md` |
| **Como escrever e operar HCL**: estrutura do repo, state, pins, lock, módulos, segredos, fluxo plan/apply, drift, `moved`/`import`/`removed`, testes, política | **esta skill** | `references/*.md` abaixo |
| Segredo e cofre (política geral) | `schematize-infra` | `schematize-infra → references/segredos.md`; aqui só o específico de IaC (`references/segredos.md`) |
| Container/imagem que a IaC referencia | `schematize-docker` | `schematize-docker → Dockerfile, supply chain` |
| Pipeline de CI/CD em geral, gates de entrega | `schematize-infra` | `schematize-infra → references/entrega.md`; aqui só o workflow de IaC |
| Teste (pirâmide, flaky, gate) | `schematize-qa` | disciplina geral; aqui o teste nativo do Terraform |
| Injeção/escalada via IaC como achado | `schematize-pentest` | lado ofensivo; aqui o construtivo |
| ADR, runbook | `schematize-docs` | decisões e procedimentos que esta skill manda escrever |

## Comandos (Claude Code)

| Comando | O que faz |
|---|---|
| `/tf-help` | lista os comandos |
| `/tf-load` | carrega à força o corpo normativo (ferramenta, estrutura, state, versões e módulos, segredos, fluxo, qualidade, providers) |
| `/tf-review` | revisa o repo IaC: roda o gate, `fmt`/`validate`/`tflint` quando houver e lê o que a máquina não lê |
| `/tf-plan` | o rito de plan: gera o plan salvo, lê na ordem certa e prepara a revisão humana. Nunca aplica |
| `/tf-module` | cria um módulo no contrato da casa (variáveis com `validation`, saídas, `versions.tf` sem provider, teste) |
| `/tf-drift` | detecta e classifica drift (`plan -detailed-exitcode`) e propõe a resolução em commit |
| `/tf-import` | adota recurso existente com bloco `import` / `moved` / `removed`, sem `state mv` à mão |
| `/tf-claude` | cria/mescla o `CLAUDE.md` sempre-on de IaC na raiz do repo |
| `/tf-cc` · `/tf-handoff` | context compact / handoff arquivado |

## Como usar

1. **Rode o gate antes de discutir estilo:** `bash scripts/check-tf.sh .` — `0` passa · `1`
   reprova · `2` **nada para verificar** (que não é aprovação). Funciona sem `tofu`/`terraform`
   e detecta qual dos dois o repo usa (lock/registry, `*.tofu`, workflow) para aplicar as regras certas.
2. **Escolha a ferramenta do repo** (`references/ferramenta.md`): OpenTofu ou Terraform, por critério
   objetivo e sem ADR obrigatório; registre no README. Nos exemplos, `$TF` = `tofu` ou `terraform`.
3. **Estruture e isole** (`references/estrutura.md`, `references/state.md`): raiz por ambiente e por
   stack, state remoto com lock e criptografia.
4. **Fixe tudo** (`references/versoes-e-modulos.md`): CLI, providers, lock multiplataforma; módulo
   como API.
5. **Segredo fora do state** (`references/segredos.md`) e **fluxo gated** (`references/fluxo.md`).
6. **Fecha com a qualidade** (`references/qualidade.md`): fmt, validate, tflint, checkov/trivy,
   teste nativo, política no plan.

Mapa de references:

| Tarefa | Reference |
|---|---|
| OpenTofu vs Terraform: critérios de escolha (licença, criptografia, features, registry, HCP, suporte), diferenças que mudam o desenho, migração | `references/ferramenta.md` |
| Layout (envs/ + modules/), por que workspace NÃO separa hml de prd, stacks e blast radius, bootstrap | `references/estrutura.md` |
| Backend, lock, criptografia (servidor e cliente), separação por ambiente, operação do state | `references/state.md` |
| `required_version`, providers com pin, `.terraform.lock.hcl` multiplataforma, contrato de módulo | `references/versoes-e-modulos.md` |
| Segredo fora do state: `ephemeral`, `*_wo`, cofre, OIDC, o que fazer se vazou | `references/segredos.md` |
| plan -> revisão -> apply gated, break-glass, drift, `moved`/`import`/`removed`, lifecycle | `references/fluxo.md` |
| fmt, validate, tflint, checkov/trivy, `tofu test`/`terraform test`, terratest, OPA/conftest, infracost, tags | `references/qualidade.md` |
| Hetzner, Cloudflare, GitHub, AWS: exemplos curtos e validados | `references/providers.md` |
| Versões, recursos por versão, SHAs de actions, o que foi executado (anexo volátil) | `references/stack-versoes.md` |

Assets prontos: `assets/repo-skeleton/` (envs/hml, envs/prd, modules/servidor com teste, lock files
reais) · `assets/repo-skeleton-terraform/` (locks do registry do Terraform) · `assets/backend/` (S3, S3-compatível, criptografia OpenTofu) · `assets/lint/.tflint.hcl` ·
`assets/policy/` (Rego + teste) · `assets/ci/github-actions-terraform.yml` e `github-actions-drift.yml`
(parametrizados por `TF_TOOL`, actions pinadas por SHA).

## Pisos inegociáveis (vetam o atalho)

1. **OpenTofu e Terraform são cidadãos de primeira classe: sem default, sem ADR obrigatório.**
   A escolha é por repo (README/ADR do projeto, critérios em `references/ferramenta.md`). **UMA
   ferramenta por repositório** (o lock carrega o registry), nunca misturar.
2. **Raiz por ambiente, nunca `workspace` para separar hml de prd.** Workspace compartilha backend,
   credencial e código; separa só o nome do state.
3. **State remoto, com lock, versionado e criptografado**, um por ambiente e por stack. **State em
   claro é vetado nas duas**: OpenTofu com `encryption { ... enforced = true }`; Terraform com backend
   de criptografia server-side + KMS e acesso restrito. Backend local em código de ambiente é vetado.
   Nunca `*.tfstate` ou `*.tfplan` no git.
4. **`required_version` e `required_providers` com `version`** (raiz: `~>` ou intervalo fechado),
   **`.terraform.lock.hcl` commitado** com hashes de **todas** as plataformas.
5. **Módulo é API:** variáveis com `type`, `description` e `validation`; saídas mínimas; segredo
   `sensitive`; **nunca `provider {}` dentro de módulo filho**; versão pinada ao consumir.
6. **Segredo nunca em `.tf`, `.tfvars` ou `default`.** Prefira o que não entra no state
   (`ephemeral` + `*_wo`, cofre lido em runtime); o que entrar, com state cifrado e acesso mínimo.
7. **plan salvo -> revisão humana -> apply só desse plan** (o artefato da mesma execução do CI).
   Apply de prd só pelo CI, no *environment* protegido; **nunca `apply` local em prd**. **A IA nunca
   roda `apply`/`destroy`/`state *` local (nem em hml): pede a operação nomeada ao ops** (`references/fluxo.md` §1.1).
   CI só em `workflow_dispatch` + tags `hml-*`/`v*`, nunca por commit/PR, nunca apply em push de branch (piso 27).
8. **Recurso com dado leva `prevent_destroy`** (e a proteção do provedor); `count` sobre recurso
   com estado é vetado — use `for_each` com chave estável.
9. **Refatorar com `moved`/`import`/`removed`**, não com `state mv/rm` à mão.
10. **Drift se detecta** (`plan -detailed-exitcode`, sob demanda; cron só com `# justificativa:`) e se
    resolve por commit no git, nunca por convivência.
11. **Tags/labels obrigatórias** (`env`, `owner`, `project`, `managed_by`) em tudo que aceita,
    validadas no módulo e na política do plan.
12. **Qualidade em degraus que travam:** `fmt`, `validate`, `check-tf.sh`, `tflint`, `checkov`/`trivy`,
    `$TF test`, `conftest` — nesta ordem: por commit, local (pre-commit/`tools/ci.sh`); no CI remoto, uma vez antes de promover a hml. Exceção só com motivo escrito. `check-tf.sh` também roda `check-ci-triggers.sh` sobre os workflows.
13. **Efeito externo nunca sai de não-produção** também em IaC (`schematize-infra → references/iac-efeitos-externos.md`).
14. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

<!-- herdado:engineering/pisos-22-29:bloco -->**Herda os pisos 22–29 da `schematize-engineering`** (texto completo em `assets/CLAUDE.md` dela): 22 tudo no git — sem remote, push falho ou HEAD≠origin a demanda NÃO se conclui; 23 deploy só do git (VETADO scp/rsync/tar|ssh/docker save|load/git bundle); 24 o ops é o gate da IA — a IA nunca muda a VPS direto nem escreve SQL, só operação nomeada (`ssh vps "ops <op>"`); 25 sem agents inúteis (entregou, morreu); 26 relatório a cada 30 min e handoff a cada 6 h; 27 CI remoto só antes do hml, a pedido ou em tag (`workflow_dispatch` + `hml-*`/`v*`; VETADO `pull_request`, `push` em branch, `workflow_run`, cron sem justificativa); 28 microserviço autônomo (fila durável + 7 testes de resiliência); 29 build/teste na máquina dev/hml quando existe (ponte só no workspace de build, nunca prd) + higiene (`scripts/higiene.sh`).<!-- /herdado -->

## Regra de mídia

Diagrama de arquitetura vai em Mermaid ou texto no repo. Imagem ou mídia gerada **nunca** por
modelo Claude: detecte Codex e Gemini disponíveis e **pergunte ao usuário qual usar**. Nenhum
disponível: avise sem rodeio que visual gerado pelo Claude tem qualidade inversamente proporcional
à de código (sai ruim de verdade) e ofereça alternativas — instalar Codex ou Gemini, imagem de
banco com licença comercial, ou asset do cliente. Claude é o melhor em código.

## Relação com as outras skills

- **`schematize-infra`** — a plataforma onde a IaC roda: isolamento, entrega, DR, rede, o
  `<projeto>_ops`. Esta skill cuida do **como o HCL é escrito e aplicado**; a infra, do **que ele
  monta e como se recupera**.
- **`schematize-engineering`** — a base: DoD, archive, IAM, efeito externo e o fluxo de ambientes
  (`operacao.md`, `ops.md`).
- **`schematize-docs`** — ADR (ferramenta, backend, chave de criptografia) e runbook (bootstrap do
  state, restauro, break-glass).
- **`schematize-docker`** — a imagem e o runtime que o recurso de IaC aponta.
- **`schematize-qa`** — a pirâmide de teste; o teste de módulo daqui é a camada de baixo.
- **`schematize-pentest`** — permissão ampla, bucket público e segredo no state são achados dela;
  aqui é o lado construtivo.
