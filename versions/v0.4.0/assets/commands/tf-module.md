---
description: schematize-terraform — cria um módulo Terraform/OpenTofu no contrato da casa (validation, saídas, versions.tf sem provider, teste nativo)
argument-hint: "<nome-do-modulo>"
---

# /tf-module — módulo é API

Crie `modules/${ARGUMENTS}/` (`references/versoes-e-modulos.md` §2). Parta de
`.claude/skills/schematize-terraform/assets/repo-skeleton/modules/servidor/`.

1. **Antes de criar:** o desenho aparece 2+ vezes ou há fronteira de responsabilidade? Wrapper fino
   de um recurso só não é módulo.
2. **Arquivos:** `versions.tf` (só `required_version` piso + `required_providers` com intervalo
   fechado; **sem `provider {}`**), `variables.tf`, `main.tf`, `outputs.tf`, `README.md`,
   `tests/<nome>.tftest.hcl`.
3. **Variáveis:** `type` + `description` em todas; `validation` em tudo que tem domínio (enum,
   regex de nome, CIDR, regra cruzada); **default só quando seguro**; segredo `sensitive`/`ephemeral`
   e sem default; objetos tipados em vez de dez variáveis soltas.
4. **Recursos:** `for_each` com chave estável (não `count` sobre lista); `prevent_destroy` e
   proteção do provedor onde há dado; labels/tags mescladas (`env`, `owner`, `project`, `managed_by`).
5. **Saídas:** o mínimo, com `description`; `sensitive` se for segredo (e pergunte se precisa existir).
6. **Teste** com `mock_provider` (`references/qualidade.md` §3): um `plan` válido + um
   `expect_failures` para cada `validation` — o vermelho primeiro.
7. **Prove** (`$TF` = `tofu` ou `terraform`, o do repo): `$TF fmt`, `$TF init -backend=false`, `$TF validate`, `$TF test`, e
   `bash .claude/skills/schematize-terraform/scripts/check-tf.sh .`. Diga o que não rodou.
8. Se usar recurso exclusivo de uma ferramenta (OpenTofu: `enabled`, `encryption`; Terraform: `actions`), declare no README e em `required_version`.
