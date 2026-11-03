# Fluxo: plan, revisão, apply gated, drift, refatoração segura

## 1. O ciclo

```
commit local (gate: fmt/validate/check-tf/tflint no pre-commit) -> push no git
    ->  tag hml-* (ou workflow_dispatch): qualidade -> plan SALVO (artefato desta execução)
    ->  revisão humana do plan -> aprovação no environment hml -> apply do MESMO artefato
    ->  tag v*: o mesmo para prd (2 aprovadores)
```

Piso 27: o CI remoto roda **uma vez por promoção** (tag `hml-*`/`v*` ou `workflow_dispatch`), nunca por
commit nem por PR, e **nunca há apply em push de branch**. O gate por commit é local.

Pisos:
1. **`plan` antes de `apply`, sempre**, e o plan que se revisa é o plan que se aplica: o job de
   apply baixa o **artefato gerado pela mesma execução** do CI (`run_id`), nunca recalcula. Se o
   revisor pede mudança, o plan antigo morre: novo commit, nova tag, novo plan. O lock do state
   garante o resto: state mudou entre plan e apply, a ferramenta recusa o plan obsoleto.
2. **Plan salvo como artefato**: `$TF plan -out=plano.tfplan`; o `apply` consome **esse arquivo**
   (`$TF apply plano.tfplan`). Sem `-auto-approve` em plan recalculado: entre o plan e o apply o
   mundo pode ter mudado, e o apply recalculado aplica algo que ninguém leu. Plan aplicado de
   state obsoleto é **recusado** pela ferramenta (isso é desejado).
3. **Apply de prd só pelo CI**, no *environment* protegido (revisores obrigatórios; só `main`, `hml-*`, `v*`).
   **Nunca `apply` local em prd.** Nem "só dessa vez". Emergência = break-glass (§3).
4. **hml antes de prd**, mesmo código. O que passou em hml sem ninguém olhar não prova nada em prd.
5. **Plan salvo é segredo em potencial**: retenção curta, repo privado; `encryption.plan` (enforced) no OpenTofu, e no Terraform acesso mínimo ao artefato (não há criptografia de plan).
6. **Um apply por vez por ambiente** (`concurrency` por ambiente nos jobs de apply, com `cancel-in-progress: false`
   justificado em comentário, + lock do state). O workflow em si usa `cancel-in-progress: true` (piso 27).

## 1.1. Identidade da IA (pisos 15, 22 e 24)

- A IA **nunca roda `apply`, `destroy` ou `state *` (`mv`/`rm`/`push`/`import`), `force-unlock` nem `-auto-approve`**
  local, nem em hml, nem em efêmero compartilhado. Quem muda infra é o CI (apply gated) ou uma operação
  nomeada do ops.
- A IA **pede a operação nomeada ao ops** (ex.: `ops tf apply --env hml --plan <artefato>`), com o commit/tag
  e o artefato do plan; a resposta (log, resumo do plan) volta como leitura.
- Credencial da IA: **somente leitura** (a do ambiente `*-plan`), nunca a de escrita do `hml`/`prd`. Com ela
  a IA roda só `fmt`, `validate`, `plan` (`-lock=false` quando só inspeciona) e `show`; apaga `plano.*` local ao fim.
- Mudança de infra é commit no git (piso 22); a trava de conclusão é remote + push + HEAD==origin.

## 2. Como se lê um plan (rito, `/tf-plan`)

Ordem de leitura:
1. **Resumo**: `N to add, N to change, N to destroy`. O número de `destroy` é a primeira coisa.
2. **Todo `destroy` e todo `must be replaced` (`-/+`)**: o que é? Tem dado? Por que o atributo
   mudou (`forces replacement`)? Recurso com estado (banco, volume, IP fixo, bucket, zona DNS)
   que será recriado é **alarme**, não detalhe.
3. **`known after apply` em campo que não deveria**: indica dependência trocada ou módulo
   reescrito.
4. **Mudança que você não escreveu** (`~` num recurso que a mudança não tocou): é drift, ou bump de
   provider mudando default. Descubra antes de aprovar.
5. **Segurança**: abertura de firewall, política IAM ampla, bucket público, remoção de
   criptografia/proteção. Os gates pegam o óbvio; você pega o contexto.
6. **Custo**: recurso novo caro? (`infracost`, `references/qualidade.md` §6.)
7. **Aprovação**: quem aprova **não é** quem escreveu (em prd, 2 pessoas). Aprovar é afirmar
   "li o plan", não "li o diff do código".

Plan que o revisor não consegue ler (milhares de linhas): a mudança está grande demais — divida por stack.

## 3. Break-glass (emergência)

Produção caiu e o pipeline não serve? Apply manual é **exceção auditada**: credencial de
emergência de uso único, dupla checagem, tudo registrado no archive (`schematize-archive`), e o
estado volta ao código **no mesmo dia** (a mudança manual vira commit no git). Quem executa o
break-glass é o humano/ops com a credencial de emergência, nunca a IA (§1.1). Estado divergente que sobrou
é drift (§4) e abre pendência.

## 4. Drift: o mundo mudou fora do código

- **Detecção sob demanda**: `plan -detailed-exitcode` por ambiente com credencial somente
  leitura (`assets/ci/github-actions-drift.yml`), disparado por `workflow_dispatch` (ops ou usuário). Sem cron por
  padrão (piso 27); agendar exige a linha `# justificativa:` no workflow. Exit `2` = drift → abre issue. `1` = erro do job.
- **Causas**: console clicado, outro automatismo, o provedor alterou default, recurso apagado.
- **Resolução**: (a) o código está certo → `apply` traz o mundo de volta; (b) a mudança era
  legítima → **vira commit no git** e o drift some. Nunca "convive com o drift" nem "ignora o diff".
- **`ignore_changes`** é para atributo que *outro sistema legitimamente gere* (ex.: `desired_count`
  gerido por autoscaling); registre o motivo em comentário. Não use para calar drift incômodo.
- `plan -refresh-only` mostra só o que mudou no mundo (sem mudanças de código); `apply -refresh-only`
  atualiza o state sem tocar na infra — use depois de decidir que o mundo é a verdade.

## 5. Refatorar sem tocar no state à mão: `moved`, `import`, `removed`

`state mv`/`rm`/`import` por comando não passam pelo git nem deixam trilha. Use os **blocos**:

```hcl
# Renomear/mover recurso ou módulo sem recriar (Terraform 1.1+, OpenTofu 1.6+)
moved {
  from = hcloud_server.app
  to   = module.app.hcloud_server.this
}

# Adotar recurso existente no state (Terraform 1.5+, OpenTofu 1.6+); com for_each desde 1.7
import {
  to = hcloud_firewall.base
  id = "123456"
}

# Tirar do state SEM destruir o objeto real (Terraform 1.7+, OpenTofu 1.7+)
removed {
  from = hcloud_server.legado
  lifecycle {
    destroy = false
  }
}
```

Rito: escreva o bloco e faça commit → `plan` mostra `will be moved/imported/removed from state` e
**nenhum destroy** → revisão → apply → **mantenha** o bloco por um ciclo de releases (módulos
publicados mantêm `moved` para quem atualiza depois) e remova quando todos os states migraram.
`plan -generate-config-out=gerado.tf` (import; confira se a sua versão suporta) gera o HCL de um recurso importado; revise
antes de adotar (vem com atributos computados e pode embutir segredo).

`terraform state mv/rm/import` por linha de comando só em recuperação, registrada.

## 6. Lifecycle

| Argumento | Quando |
|---|---|
| `prevent_destroy = true` | **todo** recurso com dado ou impossível de recriar (banco, volume, bucket, IP, zona DNS, chave KMS). Faz o plan que destruiria **falhar**. Para destruir de propósito: commit que remove a trava, revisado |
| `create_before_destroy = true` | recurso que não pode ficar fora do ar na troca (certificado, instância atrás de LB). Atenção a nomes únicos |
| `ignore_changes = [...]` | atributo gerido por outro sistema; com comentário do porquê. Nunca `all` |
| `replace_triggered_by = [...]` | forçar recriação quando outro recurso muda |
| `precondition`/`postcondition` | invariantes que o plano deve respeitar (ex.: "região permitida") |
| `enabled` (OpenTofu 1.11+) | 0/1 instância sem `count` |

`prevent_destroy` não protege contra `terraform destroy` de um **módulo removido do código**
(o recurso some da configuração, então a trava some junto). Para tirar do código sem destruir:
bloco `removed`. Para proteger de verdade o dado: também a proteção do provedor
(`delete_protection`, versionamento de bucket, backup) — `schematize-infra → resiliencia.md`.

## 7. Comandos que pedem cuidado

| Comando | Cuidado |
|---|---|
| `apply -auto-approve` | só em ambiente efêmero. Em hml/prd, só aplicando plan salvo aprovado |
| `-target` / `-exclude` | emergência registrada; depois, plan completo vazio |
| `destroy` | gated como apply; em prd, ADR ou aprovação nomeada |
| `-replace=addr` | recria um recurso de propósito (substitui o antigo `taint`); revise no plan |
| `state rm/mv/push`, `force-unlock` | recuperação, com registro |
| `-refresh=false` | esconde drift; só para diagnóstico |
| `TF_LOG=trace` | despeja credencial no log; nunca em CI compartilhado |

## 8. Efeito externo

Recurso que **dispara** efeito no mundo (e-mail, webhook, DNS de envio, cobrança) não é aplicado
com valor real fora de prd. DNS de teste em rota nula, egress SMTP bloqueado e demais camadas:
`schematize-infra → references/iac-efeitos-externos.md`. O `plan` de hml/dev que aponta para
domínio de e-mail real é achado de revisão.
