---
description: schematize-terraform — adota recurso existente com blocos import/moved/removed (sem state mv/rm à mão), com plan que prova zero destroy
argument-hint: "<tipo.nome> [id-real]"
---

# /tf-import — adotar e refatorar sem tocar no state à mão

`state mv`, `state rm` e `import` por linha de comando não passam pelo git nem deixam trilha. Use os
blocos (`references/fluxo.md` §5).

1. **Qual é o caso?**
   - **Adotar** recurso que existe no mundo e não no state -> bloco `import { to = ..., id = "..." }`.
   - **Renomear/mover** (recurso para módulo, módulo para outro nome) -> bloco `moved { from, to }`.
   - **Soltar do state sem destruir** -> bloco `removed { from = ..., lifecycle { destroy = false } }`.
2. **Escreva o recurso** no HCL com os atributos reais. Para adotar, opcionalmente gere o esqueleto:
   (`$TF` = `tofu` ou `terraform`, o do repo.) `$TF plan -generate-config-out=gerado.tf` e **revise** (traz atributos computados e pode
   conter segredo) antes de incorporar.
3. **Plan:** `$TF plan -out=plano.tfplan` deve mostrar `will be imported` / `has moved` /
   `will be removed from state` e **zero destroy, zero replace**. Qualquer destroy: pare e entenda.
4. **Commit com o plan** (`/tf-plan`), revisão, apply pelo CI/ops.
5. **Depois:** mantenha `moved` por um ciclo de releases se o módulo é compartilhado; remova
   `import` e `removed` depois de aplicados. Rode `check-tf.sh` e confirme `plan` vazio.
6. Recurso adotado com dado: já entra com `prevent_destroy` e a proteção do provedor.
