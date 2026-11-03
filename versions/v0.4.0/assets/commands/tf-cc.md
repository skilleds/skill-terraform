---
description: schematize-terraform — context compact: grava o handoff no archive e roda /compact.
---
Antes de compactar, **grave o handoff** em `<projeto>/<projeto>_archive/context/` no par
**context + checklist** do padrão da `schematize-archive` (prefixo `AAAA-MM-DD-<slug>-`), FEITO vs
ABERTO. Inclua: o que foi revisado/escrito de IaC, os achados do `scripts/check-tf.sh` que ficaram
abertos, os plans pendentes de aprovação e as exceções (`# tf-ok:`) declaradas, com o motivo. Nunca
inclua plan, state ou segredo. Só então rode `/compact`.
