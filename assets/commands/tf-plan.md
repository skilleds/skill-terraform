---
description: schematize-terraform — rito de plan: gera o plan salvo, lê na ordem certa e prepara a revisão humana. Nunca aplica.
argument-hint: "<envs/ambiente>"
---

# /tf-plan — o plan é o contrato; quem aprova leu

Alvo: `envs/${ARGUMENTS}` (ex.: `envs/hml`). **Este comando NÃO aplica.** `apply` é do CI, no
*environment* protegido, consumindo o plan aprovado, ou de operação nomeada do ops; a IA nunca aplica (`references/fluxo.md`).

1. **Pré-condições:** árvore limpa; credencial **somente leitura** (nunca a de escrita); ferramenta
   e versão iguais às do CI (`required_version`).
2. **Gate:** `bash .claude/skills/schematize-terraform/scripts/check-tf.sh .` — reprovou, pare.
3. **Plan salvo:**
   ```bash
   cd envs/<ambiente>
   $TF init -input=false
   $TF plan -input=false -lock-timeout=5m -var-file=<ambiente>.tfvars -out=plano.tfplan
   $TF show -no-color plano.tfplan > plano.txt
   $TF show -json plano.tfplan > plano.json
   conftest test --policy ../../policy plano.json
   ```
   (`$TF` = `tofu` ou `terraform`, o do repo: lock/README/workflow.) `plano.tfplan` e `plano.json` podem conter segredo: não
   commite, não cole em chat/issue sem filtrar.
4. **Leia nesta ordem** e escreva o resumo (`references/fluxo.md` §2):
   - totais: add / change / **destroy**;
   - cada `destroy` e cada `must be replaced`: o que é, tem dado, por que o atributo mudou;
   - mudanças em recurso que a mudança **não** tocou (drift ou bump de provider);
   - abertura de rede, permissão ampla, remoção de proteção/criptografia;
   - `known after apply` onde não devia; custo se houver `infracost`.
5. **Entregue** ao humano: resumo + veredito (`SEGURO PARA APROVAR` / `PEDE ATENÇÃO` / `BLOQUEAR`)
   com o motivo de cada ponto de atenção. Quem aprova **não é** quem escreveu.
6. **Apague** `plano.*` locais ao fim. O artefato oficial é o do CI.
