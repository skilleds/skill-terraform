# Segredos em IaC

> Regra mãe da casa (`schematize-infra → references/segredos.md`, `schematize-engineering`):
> segredo **nunca** em repositório, **nunca** em log, **nunca** em claro onde não precisa estar.
> Segredo que já foi commitado: tratar como vazado (revogar, rotacionar, limpar o histórico) —
> `schematize-git → references/segredos.md`.
> IaC é o lugar onde isso mais vaza, porque o state e o plan **guardam tudo**.

## 1. Os cinco vazamentos clássicos

| Vazamento | Por quê | Piso |
|---|---|---|
| `password = "..."` no `.tf` ou valor no `.tfvars` commitado | entra no git para sempre | gate `segredo-literal`; valor vem do ambiente/cofre |
| `default = "..."` em variável de segredo | idem, e vira o valor "oficial" | proibido (`segredo-literal`) |
| Segredo no **state** | todo atributo do provider vai em claro para o state | `ephemeral`/write-only; criptografia do state; acesso mínimo |
| Segredo no **plan** salvo (artefato do CI) | o plan contém os valores | retenção curta, repo privado; OpenTofu: `encryption.plan` (enforced); Terraform: acesso mínimo ao artefato |
| Segredo em **log** do CI | `TF_LOG=trace`, `-var` em argumento, `output` sem `sensitive` | `sensitive`, mascarar, nunca `-var 'x=segredo'` |

`sensitive = true` **não protege o state**: só oculta do terminal e do plan renderizado.

## 2. A escada (do melhor ao pior)

1. **Nem passa pelo Terraform.** O recurso lê o segredo do cofre em runtime (a app pega do
   Vault/OpenBao/Secrets Manager com a identidade dela). IaC cria o *cofre e a permissão*, não o valor.
2. **Valor efêmero (`ephemeral`) + argumento write-only (`*_wo`).** O segredo existe só durante
   o plan/apply, **não é gravado em state nem em plan**.
3. **Data source do cofre** com `sensitive` e state cifrado. Gravado no state (cifrado). Aceitável
   quando o provider ainda não tem write-only; registre a dívida.
4. **Variável de ambiente (`TF_VAR_x`)** injetada pelo CI a partir de secret do ambiente protegido.
   O valor entra no state se o recurso o persiste.
5. **`.tfvars` com segredo / literal no `.tf`**: **vetado.**

## 3. Efêmero e write-only (verificar a versão antes)

Disponível em: **Terraform 1.10** (valores e recursos efêmeros) e **1.11** (argumentos write-only);
**OpenTofu 1.11** (ambos); vale para as duas ferramentas. Fonte e data em `stack-versoes.md`.

```hcl
# 1) lê o segredo do cofre: efêmero, não vai ao state
ephemeral "aws_secretsmanager_secret_version" "db" {
  secret_id = "prd/db/admin"
}

# 2) usa em argumento write-only: o provider recebe, o state não guarda
resource "aws_db_instance" "principal" {
  # ...
  username            = "admin"
  password_wo         = jsondecode(ephemeral.aws_secretsmanager_secret_version.db.secret_string)["password"]
  password_wo_version = 1   # incremente para rotacionar (write-only não tem diff)
}
```

Pontos que mordem:
- **Write-only não tem diff.** Para rotacionar, mude o `*_wo_version` (ou equivalente do provider).
- **Só provider atualizado** oferece `*_wo` e recursos `ephemeral`. Hoje: `aws_db_instance.password_wo`
  existe; muitos recursos ainda não têm — cai no degrau 3 com o state cifrado. <!-- reverificar por provider -->
- **Valor efêmero só em contexto efêmero**: em `provider {}`, em `*_wo`, em `locals`/variáveis/
  outputs marcados `ephemeral`, em `provisioner`/`connection`. Usar em atributo normal é erro.
- Variável de entrada: `variable "x" { type = string  ephemeral = true }` — não persiste no plan.
- Saída de módulo raiz: `output "x" { value = ...  ephemeral = true }` (não gravada).
- No OpenTofu, `lifecycle { enabled }` não aceita valor efêmero (documentado).
- Provider que precisa de credencial de cofre (Vault, Kubernetes): configure o provider com
  `ephemeral` para o token não ir ao state. Fonte: cada provider documenta quais recursos efêmeros tem.

## 4. Data source do cofre quando não há efêmero

```hcl
data "vault_kv_secret_v2" "db" {      # ou aws_secretsmanager_secret_version, etc.
  mount = "kv"
  name  = "prd/db"
}
# data_json é sensível e FICA NO STATE: criptografe o state (OpenTofu: `encryption`; Terraform: backend com KMS) e limite o acesso.
```
Nunca "traga" o segredo para uma variável de entrada só para repassá-lo: leia direto do cofre
(menos um lugar onde o valor passa).

## 5. Credencial do próprio provider/CI

- **OIDC (federação) no CI**, sem chave estática: GitHub Actions → role/identidade da nuvem
  com `id-token: write`, escopo por ambiente (`hml-plan` somente leitura; `prd` escrita só no
  job de apply, atrás de aprovação).
- Provedor sem OIDC (Hetzner, Cloudflare): token de **escopo mínimo** por ambiente, como
  *secret do GitHub Environment* (nunca de repositório inteiro), rotacionado por calendário;
  o provider lê da variável de ambiente (`HCLOUD_TOKEN`, `CLOUDFLARE_API_TOKEN`, `GITHUB_TOKEN`) —
  **não** declare `token = var.x`.
- **Plan** usa credencial **somente leitura**; **apply** usa escrita. Duas identidades.
- Ninguém roda `apply` de prd do laptop com credencial pessoal (`references/fluxo.md` §3).

## 6. Se vazou

1. **Revogue e rotacione** o segredo (o git/log/state já foi lido por alguém ou algum bot).
2. Remova do histórico (`git filter-repo`) **depois** de rotacionar — apagar sem rotacionar é teatro.
3. Se estava no state: rotacione, e rode `apply` que grave o novo valor (ou use write-only).
4. Registre o incidente e a causa; incidente repetido vira piso + gate (como aqui).
