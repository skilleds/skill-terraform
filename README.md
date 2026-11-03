# schematize-terraform — IaC com OpenTofu e Terraform

> **O state é a memória da infra e o plan é o contrato.** IaC declarativa em **OpenTofu e
> Terraform**, em paridade (uma ferramenta por repo, escolhida por critério objetivo): raízes por ambiente, state remoto com lock e
> criptografia, providers e lock file fixados, módulos como API, segredo fora do state, plan salvo
> com apply gated, drift sob demanda, testes e política como código.

Pacote de **skill normativa para [Claude Code](https://claude.com/claude-code)**.
Parte do catálogo **schematize skills**.

## Por que ela existe

A `schematize-infra` cobre a plataforma (isolamento, entrega, DR, rede) e trata IaC como
princípio. Faltava a **especialista**: o que fazer com o HCL — onde guardar o state, por que
`workspace` não separa produção de homologação, como fixar provider e lock file, como escrever
módulo, como manter segredo fora do state, como aplicar sem `apply` na máquina de ninguém. Tudo isso
já foi incidente em algum lugar.

## Instalar

### Pelo app schematize (recomendado)

```bash
schematize install terraform    # requer o CLI schematize instalado
```

### Manual

```bash
git clone https://github.com/schematizeme/skill-terraform.git /tmp/skill-terraform
bash /tmp/skill-terraform/install.sh .        # instala em .claude/ do projeto atual
```

## O que tem dentro

- **SKILL.md** — o contrato: 14 pisos inegociáveis, a fronteira com a `schematize-infra` e o mapa de references.
- **references/** — `ferramenta` (OpenTofu vs Terraform), `estrutura`, `state`, `versoes-e-modulos`,
  `segredos`, `fluxo`, `qualidade`, `providers` (Hetzner, Cloudflare, GitHub, AWS) e `stack-versoes`
  (anexo volátil com data, fontes e o que foi executado).
- **scripts/** — `check-tf.sh`, o gate estático (funciona **sem** `tofu`/`terraform`, detecta qual o repo usa e aplica as regras certas; waiver
  rastreável `# tf-ok:`), e `check-tf.test.sh` (48 casos, vermelhos plantados).
- **assets/** — `repo-skeleton/` (envs/hml, envs/prd, modules/servidor com teste e lock files reais; `encryption.tofu` só para OpenTofu) e `repo-skeleton-terraform/` (locks do registry do Terraform),
  `backend/` (S3, S3-compatível, criptografia do OpenTofu), `lint/.tflint.hcl`, `policy/` (Rego +
  teste), `ci/` (workflow de IaC e de drift, actions pinadas por SHA), `commands/`, `CLAUDE.md`.

## Comandos

| Comando | O que faz |
|---|---|
| `/tf-help` | lista os comandos |
| `/tf-load` | carrega à força o corpo normativo |
| `/tf-review` | revisa o repo IaC: gate + ferramentas + leitura humana |
| `/tf-plan` | rito de plan: salvo, lido na ordem certa, revisão humana (nunca aplica) |
| `/tf-module` | scaffold de módulo no contrato da casa |
| `/tf-drift` | detecta e classifica drift |
| `/tf-import` | `import`/`moved`/`removed` em vez de `state mv` |
| `/tf-claude` | `CLAUDE.md` sempre-on de IaC |
| `/tf-cc` · `/tf-handoff` | context compact / handoff |

## Verificação

```bash
bash scripts/check-tf.test.sh        # vermelho primeiro do gate
bash scripts/check-tf.sh assets/repo-skeleton   # o esqueleto passa no próprio gate
```

## Licença

MIT. Ver `LICENSE` (inclui avisos de marcas de terceiros).
