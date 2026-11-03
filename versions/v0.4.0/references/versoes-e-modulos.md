# Versionamento e módulos

## 1. Versões: tudo fixado, nada solto

### 1.1 A CLI
```hcl
terraform {
  required_version = ">= 1.9.0, < 2.0.0"   # raiz: intervalo que você testou
}
```
Raiz: fixe um intervalo estreito e **a mesma versão exata no CI** (`tofu_version`). Módulo
compartilhado: só o piso (`>= 1.9.0`), porque quem decide a versão é a raiz.

### 1.2 Providers
```hcl
required_providers {
  hcloud = {
    source  = "hetznercloud/hcloud"   # sempre com source explícito
    version = "~> 1.70"               # raiz: ~> (teto implícito); módulo: ">= 1.50, < 2.0"
  }
}
```
- **Sem `version` = provider solto**: o próximo `init` sobe major e quebra o plano (`provider-sem-pin`).
- **Raiz sem teto** (`>= 1.50`) também reprova (`provider-sem-teto`). Módulo pode usar `>=` com
  teto de major.
- Forma legada (`aws = "~> 5.0"`, string) não tem `source`: reprova.

### 1.3 O lock file
`.terraform.lock.hcl` **é commitado**, sempre. Ele fixa a versão **exata** e os **hashes** dos
binários de provider: é a cadeia de suprimentos do provider (um provider adulterado no registry ou
no mirror não bate o hash).

**Multiplataforma**: o `init` numa máquina só grava o hash daquela plataforma; o CI (outra
plataforma) falha com "provider checksum mismatch" ou reescreve o lock. Gere para todas:

```bash
$TF providers lock \
  -platform=linux_amd64 -platform=linux_arm64 \
  -platform=darwin_amd64 -platform=darwin_arm64 \
  -platform=windows_amd64
```
O gate exige **≥ 2 hashes `h1:`** por provider (`lock-sem-multiplataforma`). Comando
`/tf-review` confere. O lock é regenerado em PR próprio ("bump de provider"), nunca por acidente
no meio de outra mudança.

### 1.4 Atualizar
PR dedicado: sobe a constraint, `$TF init -upgrade`, `providers lock` multiplataforma, `plan`
**vazio** (ou só o diff esperado) em hml, `plan` em prd. Leia o changelog do provider: major
costuma renomear recurso (ex.: Cloudflare v4→v5 trocou `cloudflare_record` por `cloudflare_dns_record`).
Bots (Renovate/Dependabot) abrem o PR; a regra de revisão é a mesma.

## 2. Módulos: contrato

Um módulo é uma **API**. Trate como tal.

### 2.1 Entradas
```hcl
variable "ambiente" {
  description = "Ambiente dono do recurso."
  type        = string                       # SEMPRE type
  validation {
    condition     = contains(["hml", "prd"], var.ambiente)
    error_message = "ambiente deve ser hml ou prd."
  }
}
```
- `type` e `description` em **toda** variável (o `tflint` cobra).
- **`validation`** para tudo que tem domínio: enum, regex de nome, CIDR (`can(cidrhost(...))`),
  faixa numérica, **regra cruzada entre variáveis** (a partir de TF 1.9/Tofu 1.9 a condição pode
  referenciar outras variáveis — ex.: "SSH aberto ao mundo vetado em prd").
- **Default só quando seguro.** Default inseguro (`0.0.0.0/0`, `publico = true`) é bug de API.
  O valor perigoso deve ser pedido, nunca herdado.
- Variável de segredo: `sensitive = true` (ou `ephemeral = true` — `references/segredos.md`);
  nunca `default` literal (`variavel-sensivel`, `segredo-literal`).
- Prefira objetos tipados (`object({...})`, com `optional()`) a dez variáveis soltas.

### 2.2 Saídas
Exponha o **mínimo** que o consumidor precisa (id, endpoint), com `description`. Saída que contém
segredo: `sensitive = true` (`output-sensivel`) — e pergunte antes se ela precisa existir.

### 2.3 Sem provider dentro de módulo filho
Módulo **declara** `required_providers`; **quem configura** é a raiz. `provider {}` dentro de
módulo filho impede `count`/`for_each`/`enabled` no módulo, impede destruí-lo (o provider some
junto) e esconde credencial (`provider-em-modulo`). Precisa de dois providers do mesmo tipo
(duas regiões, duas contas)? `configuration_aliases` no módulo e `providers = { aws.leste = aws.leste }`
na chamada.

### 2.4 `count`, `for_each`, `enabled`
- `for_each` sobre mapa/conjunto com **chave estável** (nome), não `count` sobre lista: remover o
  item do meio com `count` desloca os índices e **destrói e recria** os seguintes. Em recurso com
  estado (volume, banco), isso é perda de dado (`critico-sem-prevent-destroy` cobra
  `prevent_destroy` nesses casos).
- 0 ou 1 instância: OpenTofu 1.11+ tem `lifecycle { enabled = var.x }`; no Terraform use
  `count = var.x ? 1 : 0` e acesse com `[0]`/`one()`.

### 2.5 Versionar e consumir módulo
- **Local** (`source = "../../modules/servidor"`) no mesmo repo: versionado junto, sem `ref`.
- **Compartilhado**: repo próprio com tags SemVer; consumo com `?ref=v1.4.0` (git) ou
  `version = "~> 1.4"` (registry). **Nunca** `ref=main` nem versão sem pin (`terraform_module_pinned_source`).
- **Quebra de API = major.** Renomear variável, mudar default, remover output, trocar o tipo de
  recurso (força replace) — tudo isso é major, com nota de migração e blocos `moved` dentro do
  módulo para que a atualização não recrie.
- Descontinuar sem quebrar: `deprecated = "mensagem"` em variável/output (OpenTofu 1.10+; no
  Terraform 1.x ainda não) <!-- reverificar --> ou aviso no README.

### 2.6 Módulos de terceiros
Registro público (`terraform-aws-modules/*` e afins): **fixe versão**, leia o código antes de
adotar (é código que roda com sua credencial), e prefira módulo mantido por organização com
histórico. Para recurso simples, o recurso direto é mais claro que o módulo genérico de 80 variáveis.

### 2.7 Documentação e teste
README com exemplo de uso, tabela de entradas/saídas (gerada: `terraform-docs`) e a nota de
ferramenta (se usa recurso exclusivo de uma das ferramentas, p. ex. `enabled`/`encryption` do OpenTofu). Teste nativo em `tests/*.tftest.hcl` com
`mock_provider` (`references/qualidade.md` §3).
