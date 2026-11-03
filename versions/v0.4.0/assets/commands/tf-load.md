---
description: schematize-terraform — carrega à força TODO o corpo normativo de IaC (OpenTofu/Terraform) e passa a aplicá-lo nesta sessão.
---
Carregue **agora** o corpo normativo da skill `schematize-terraform`. A partir daqui, nesta sessão,
isto **não é opcional**.

1. **Leia na íntegra, sem trabalhar de memória.** Caminho:
   `.claude/skills/schematize-terraform/references/*.md` (projeto) ou
   `~/.claude/skills/schematize-terraform/references/*.md` (global):
   - `ferramenta.md` — OpenTofu e Terraform em paridade, critérios de escolha por repo; uma ferramenta por repo;
     o que só existe de um lado (criptografia de state, `enabled`).
   - `estrutura.md` — `envs/` + `modules/`; **por que workspace não separa hml de prd**; stacks e
     blast radius; bootstrap do state.
   - `state.md` — backend remoto com lock nativo (`use_lockfile`), criptografia (servidor e cliente),
     separação por ambiente, operação do state.
   - `versoes-e-modulos.md` — `required_version`, providers com pin, lock multiplataforma, contrato de
     módulo, sem `provider {}` em módulo filho.
   - `segredos.md` — a escada: fora do state > `ephemeral`/`*_wo` > cofre > env; OIDC; se vazou.
   - `fluxo.md` — plan salvo, apply gated, break-glass, drift, `moved`/`import`/`removed`, lifecycle.
   - `qualidade.md` — fmt, validate, tflint, checkov/trivy, `tofu test`/`terraform test`, OPA/conftest, infracost, tags.
   - `providers.md` — Hetzner, Cloudflare, GitHub, AWS.
   - `stack-versoes.md` — anexo volátil: versões, suporte por versão, SHAs, o que foi executado.
2. **Rode o gate no repo atual** antes de opinar sobre estilo:
   `bash .claude/skills/schematize-terraform/scripts/check-tf.sh .`
3. **Aplique daqui em diante** a todo `.tf` que você escrever ou tocar, e diga qual piso está
   aplicando quando ele mudar o que você ia fazer. **Nunca rode `apply`** sem plan salvo e aprovado.
