---
description: schematize-terraform — detecta e classifica drift (plan -detailed-exitcode) e propõe a resolução em commit; nunca aplica
argument-hint: "<envs/ambiente | todos>"
---

# /tf-drift — o mundo divergiu do código?

1. **Credencial somente leitura.** Drift se detecta sem poder escrever.
2. Para cada raiz (`envs/${ARGUMENTS}`):
   ```bash
   TF=tofu   # ou: TF=terraform (a do repo)
   $TF init -input=false
   $TF plan -input=false -lock=false -detailed-exitcode -no-color -var-file=<amb>.tfvars
   # 0 = sem mudança · 2 = DRIFT · 1 = erro (tratar como falha do job, não como drift)
   ```
   `-lock=false` só aqui (leitura; não bloqueia um apply legítimo). Para ver só o que mudou fora do
   código: `$TF plan -refresh-only`.
3. **Classifique cada diferença** (`references/fluxo.md` §4):
   - **mudança manual indevida** -> o código está certo: `apply` (por commit + tag, via CI/ops) traz o mundo de volta;
   - **mudança manual legítima** -> vira código (commit) e o drift some;
   - **default novo do provider/bump** -> ajuste explícito no código ou `ignore_changes` com motivo;
   - **atributo gerido por outro sistema** -> `ignore_changes` com comentário do porquê;
   - **recurso apagado fora** -> recriar (cuidado com dado) ou `removed` se foi intencional.
4. **Execução:** se não existe, instale `assets/ci/github-actions-drift.yml` (por `workflow_dispatch`, abre issue; cron só com `# justificativa:`).
5. **Entregue** a tabela (recurso | o que mudou | classe | ação | dono). Resolução é commit no git; este
   comando não aplica. Drift que ninguém corrige em prazo vira item de checklist com dono.
