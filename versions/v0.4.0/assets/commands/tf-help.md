---
description: Mapa da skill schematize-terraform (IaC declarativa em OpenTofu/Terraform — o state é a memória, o plan é o contrato).
---
**schematize-terraform** — IaC com OpenTofu e Terraform, em paridade (uma ferramenta por repo; `$TF` = `tofu` ou `terraform`).

| Comando | O que faz |
|---|---|
| `/tf-help` | esta lista |
| `/tf-load` | carrega à força TODO o corpo normativo (ferramenta, estrutura, state, versões e módulos, segredos, fluxo, qualidade, providers) e passa a aplicá-lo |
| `/tf-review` | revisa o repo IaC: roda `scripts/check-tf.sh`, `fmt`/`validate`/`tflint` quando houver, e lê o que a máquina não lê |
| `/tf-plan` | o rito de plan: plan salvo, leitura na ordem certa, revisão humana. Nunca aplica |
| `/tf-module` | cria um módulo no contrato da casa (validation, saídas, versions.tf sem provider, teste) |
| `/tf-drift` | detecta e classifica drift e propõe a resolução em PR |
| `/tf-import` | adota recurso existente com `import`/`moved`/`removed`, sem `state mv` à mão |
| `/tf-claude` | cria ou mescla o `CLAUDE.md` sempre-on de IaC na raiz do repo |
| `/tf-cc` · `/tf-handoff` | context compact / handoff no archive |

Pareia com: `schematize-infra` (plataforma: isolamento, entrega, DR, rede), `schematize-docs` (ADR e
runbook), `schematize-docker` (imagem), `schematize-qa` (teste), `schematize-pentest` (achados de
permissão e segredo).
