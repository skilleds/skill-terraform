# State: remoto, com lock, criptografado e separado por ambiente

> O state é a **memória** da IaC: o mapa entre o código e os objetos reais. Quem o perde não
> consegue mais gerir a infra; quem o lê **lê segredos**; quem o corrompe pode destruir produção.
> Trate o backend como dado de criticidade máxima.

## 1. Pisos

1. **Backend remoto em toda raiz de ambiente.** `backend "local"` (ou nenhum backend) só em
   laboratório descartável, com waiver escrito. O gate `scripts/check-tf.sh` reprova
   (`backend-ausente`, `backend-local`).
2. **Lock obrigatório.** Dois `apply` concorrentes corrompem o state. Lock nativo do backend.
3. **Versionamento do objeto de state.** Permite voltar a um state anterior depois de um erro.
4. **Criptografia em repouso, em claro vetado nas duas ferramentas**: OpenTofu cifra **no cliente**
   (§4) além do server-side; Terraform exige **server-side com KMS** e acesso restrito (§4.1). O gate
   reprova (`tofu-sem-criptografia`, `terraform-state-sem-kms`).
5. **Um state por ambiente e por stack** (blast radius, §5), com credencial separada para prd.
6. **State e plan nunca no git** (`*.tfstate`, `*.tfplan` no `.gitignore`; o gate reprova se
   versionado: `state-versionado`).
7. **Acesso mínimo e auditado**: quem lê o state de prd lê todo segredo que passou por ele.

## 2. Backend S3 (e compatíveis)

```hcl
terraform {
  backend "s3" {
    bucket       = "acme-tfstate-prd"
    key          = "prd/core.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "alias/tfstate-prd"
    use_lockfile = true      # lock NATIVO no S3
  }
}
```

- **`use_lockfile = true`** é o lock nativo (arquivo `.tflock` ao lado do state, via escrita
  condicional). **`dynamodb_table` está deprecado** (Terraform: GA do lock nativo na 1.11 e
  deprecação do DynamoDB; OpenTofu acompanha). Estado legado com DynamoDB migra: habilite
  `use_lockfile`, rode com os dois, depois remova `dynamodb_table`.
- **Bucket** (criado no bootstrap): versionamento **ligado**, bloqueio de acesso público,
  política que nega acesso sem TLS, SSE-KMS com chave própria, `prevent_destroy`, logs de acesso.
- **S3-compatível** (Hetzner Object Storage, Cloudflare R2, MinIO): exige as flags `skip_*` e
  `use_path_style`; confirme que o serviço suporta escrita condicional antes de confiar no
  `use_lockfile`. Exemplo: `assets/backend/s3-compativel.tf.example`. <!-- reverificar -->
- **Backend não aceita variável** no Terraform. No OpenTofu 1.8+ aceita variável/local
  (avaliação antecipada), mas **sem valor sensível**. Para portabilidade, use valores literais
  por raiz ou `-backend-config=arquivo` (sem segredo no arquivo).
- Outros backends (GCS, azurerm, pg, http): o lock é nativo do GCS/azurerm. `pg` e `http` exigem
  conferir o lock do serviço.

Credencial do backend: **OIDC no CI**, perfil/role por ambiente. Nunca chave estática em
variável de repositório; nunca no `backend.tf`.

## 3. O que o state contém (e por que é sensível)

Todo atributo que o provider devolve entra no state **em claro**: senha gerada, chave privada de
`tls_private_key`, `secret_string` do Secrets Manager, token de `hcloud_server` com `user_data`.
`sensitive = true` **só esconde da saída do terminal** — não tira do state nem do plan.
Mitigações, em ordem de força: (1) **não pôr o segredo no state** (`ephemeral` + argumentos
`*_wo`, `references/segredos.md`); (2) **cifrar o state no cliente** (só OpenTofu, §4); (3) cifrar no
servidor com KMS e restringir acesso (a única opção do Terraform, §4.1).

## 4. OpenTofu: criptografia nativa do state e do plan

OpenTofu 1.7+ cifra state e plan **antes** de enviar ao backend (AES-GCM; chave de KMS/OpenBao/
GCP KMS/PBKDF2 ou programa externo). Efeito: um bucket exposto por engano entrega só texto cifrado.

```hcl
terraform {
  encryption {
    key_provider "aws_kms" "estado" {
      kms_key_id = "alias/tofu-state"
      region     = "us-east-1"
      key_spec   = "AES_256"
    }
    method "aes_gcm" "estado" { keys = key_provider.aws_kms.estado }
    state { method = method.aes_gcm.estado  enforced = true }
    plan  { method = method.aes_gcm.estado  enforced = true }
  }
}
```

- `enforced = true` recusa state/plan em claro (sem isso um arquivo antigo em claro passa).
- **Sem KMS**: `key_provider "pbkdf2"` com passphrase injetada por `TF_ENCRYPTION` (do cofre),
  nunca no código. Provado nesta skill: state e plan saem cifrados (`stack-versoes.md`).
- **A chave é parte do disaster recovery.** Perdeu a chave, perdeu o state. Backup da chave
  separado do backup do state, com restauro testado (`schematize-infra → references/resiliencia.md`).
- **Migração**: para ligar, use `fallback { method = ... }`/método `unencrypted` por uma rodada;
  depois remova e ponha `enforced = true`. Não existe no Terraform; migrar para lá exige
  descriptografar antes.
- Exemplo completo: `assets/backend/encryption-opentofu.tf.example`. Coloque o bloco em
  `encryption.tofu` (o Terraform ignora `*.tofu`; o esqueleto faz assim).

### 4.1 Terraform: criptografia server-side + KMS (não há criptografia de cliente)

O Terraform grava o state como veio; a proteção é do **backend**. O piso (gate
`terraform-state-sem-kms`):

- **S3**: `encrypt = true` **e** `kms_key_id = "alias/..."` (SSE-KMS, chave própria por ambiente;
  quem lê o state precisa de permissão na chave); bucket versionado, sem acesso público, política
  negando acesso sem TLS. Exemplo: `assets/backend/s3.tf.example`.
- **GCS**: `kms_encryption_key` (CMEK). **Azure**: Storage Account com chave gerenciada pelo cliente
  (o gate não prova, revise). **HCP Terraform** (`cloud {}`): o state é cifrado pelo serviço.
- **S3-compatível sem KMS** (Hetzner, R2, MinIO): o provedor cifra em repouso, mas sem chave sua;
  aceite só com waiver `# tf-ok: terraform-state-sem-kms <motivo>` que diga quem acessa o bucket,
  e prefira cofre/ephemeral para que o segredo nem entre no state.
- Compense a falta de criptografia de cliente: **segredo fora do state** (`ephemeral` + `*_wo`),
  acesso mínimo ao bucket e à chave, log de acesso ligado, plan salvo em artefato de retenção curta.

## 5. Separação por ambiente e blast radius

- **hml e prd: backend, bucket e credencial diferentes.** Idealmente contas/projetos de nuvem
  diferentes. O `key` no mesmo bucket é o mínimo, não o desejável.
- **Por stack**: rede, dados e app em states diferentes (`references/estrutura.md` §5). Um
  `apply` errado na app não enxerga o state do banco.
- **Pergunta de projeto**: "se este state for corrompido ou apagado, qual é o maior estrago, e em
  quanto tempo recupero?" Se a resposta assusta, parta o state.
- **Não use `-target` como rotina.** Aplicar parcial deixa state e código divergentes; é
  ferramenta de emergência, registrada, seguida de um plan completo vazio.

## 6. Operação do state

- `force-unlock` só quando você **provou** que o processo dono do lock morreu; registre quem e por quê.
- **Sem `state mv`/`state rm` à mão em fluxo normal:** use `moved`, `import` e `removed`
  (`references/fluxo.md` §5). O state manual não passa por PR nem deixa trilha.
- **`state pull` expõe segredo** no terminal/log. Use só com saída redirecionada para arquivo
  protegido e apague depois.
- **Recuperação**: a versão anterior do objeto de state (versionamento do bucket) + `plan` para
  conferir. Ensaie em hml (`/infra-drill`).
- **Remote state entre raízes**: evite (§5 de estrutura). Se inevitável, `terraform_remote_state`
  lê o state inteiro — o consumidor passa a ter acesso a todos os segredos dele.
