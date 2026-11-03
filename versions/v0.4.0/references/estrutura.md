# Estrutura do repositório: raízes por ambiente, módulos reutilizáveis

> Duas peças, nunca misturadas: **raiz** (root module — o que se aplica; um state por raiz) e
> **módulo** (biblioteca — o que se reutiliza; sem state próprio, sem provider configurado).

## 1. O layout da casa

```
infra/
├── envs/                      # RAÍZES: uma por ambiente (e por stack, se for o caso)
│   ├── hml/
│   │   ├── backend.tf         # state remoto DESTE ambiente
│   │   ├── versions.tf        # required_version + required_providers (pin ~>)
│   │   ├── main.tf            # provider{} + chamadas de módulo
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── hml.tfvars         # valores NÃO secretos
│   │   └── .terraform.lock.hcl   # COMMITADO, multiplataforma
│   └── prd/                   # mesma forma, valores e state próprios
├── modules/                   # MÓDULOS reutilizáveis (sem backend, sem provider{})
│   └── servidor/
│       ├── main.tf  variables.tf  outputs.tf  versions.tf  README.md
│       └── tests/servidor.tftest.hcl
├── policy/                    # OPA/conftest (política como código)
├── .tflint.hcl
└── .github/workflows/terraform.yml
```

Esqueleto pronto e validado: `assets/repo-skeleton/`.

## 2. Por que raízes por ambiente e NÃO workspaces para separar hml de prd

`terraform workspace` / `tofu workspace` troca o **state** dentro do **mesmo** backend e do **mesmo**
código. É útil para clonar efêmeros (um PR = um ambiente descartável). **Para separar produção de
homologação é a ferramenta errada**:

1. **Mesma credencial, mesmo bucket.** O workspace `prd` e o `hml` moram no mesmo backend; quem
   consegue aplicar um consegue o outro. O isolamento que a casa exige (`schematize-infra →
   references/isolamento.md`) pede credencial e bucket **diferentes** por ambiente.
2. **Selecionar o ambiente é um estado oculto.** `workspace show` é a única coisa entre você e
   o `apply` no lugar errado. Raiz por diretório é visível no caminho, no PR e no log do CI.
3. **Código idêntico não é o que se quer.** hml e prd divergem de propósito (tamanho, proteção,
   quantidade); com workspace isso vira `terraform.workspace == "prd" ? ... : ...` espalhado,
   e cada condicional é um bug esperando.
4. **Blast radius.** Um `destroy` sem querer no workspace errado leva produção. Com raízes, o
   pior `destroy` de hml não enxerga o state de prd.
5. **Revisão.** O diff de `envs/prd/` no PR é o diff do que muda em produção. Com workspace o
   PR não diz em qual ambiente o código vai agir.

Workspace é aceitável para: ambiente efêmero por PR, teste de módulo, réplica de laboratório —
sempre **fora** de prd e hml, e com nome derivado do PR.

## 3. Raiz: o que entra e o que não entra

- **Entra**: `terraform {}` (versão, providers, backend), `provider {}` (credencial via ambiente),
  chamadas de módulo, `data` sources do contexto, `output`s consumidos por outras raízes.
- **Não entra**: lógica reutilizável (vira módulo), valor secreto (vira cofre/ephemeral),
  `terraform.tfstate` ou plan (nunca no git).
- **Pequena**: uma raiz que passa de ~200 recursos ou mistura ciclos de vida diferentes (rede,
  banco, app) deve ser **partida em stacks** (§5).

## 4. Módulo: o que é e quando criar

Crie módulo quando **o mesmo desenho aparece 2+ vezes** (hml e prd contam) ou quando há uma
fronteira de responsabilidade (rede, banco, observabilidade). Não crie módulo para "organizar"
um recurso só: um wrapper fino sobre um recurso é indireção sem ganho.

Contrato de módulo: `references/versoes-e-modulos.md`. Resumo: variáveis tipadas com `validation`,
`description` em tudo, `outputs` mínimos, `sensitive` onde cabe, `required_providers` sem
`provider {}`, README, teste em `tests/`.

Origem do módulo: **local** (`../../modules/x`) dentro do repo — o caso comum; **registro/git**
com versão fixada (`?ref=v1.4.0` ou `version = "~> 1.4"`) quando o módulo é compartilhado entre
repos. Nunca `ref=main`.

## 5. Stacks e blast radius

Divida por **ciclo de vida e raio de dano**, não por gosto:

| Stack | Muda | Raio de dano | Quem aplica |
|---|---|---|---|
| `rede/` (VPC, DNS, firewall base) | raramente | enorme | plataforma, 2 aprovações |
| `dados/` (banco, volume, bucket) | raramente | perda de dado | plataforma, `prevent_destroy` |
| `app/` (servidores, serviços) | sempre | um serviço | time dono |

Cada stack é uma raiz com state próprio (`prd/rede.tfstate`, `prd/dados.tfstate`, `prd/app.tfstate`).
Uma stack lê a outra por **data source ou output publicado** — não por
`terraform_remote_state` (acopla ao *formato* do state alheio e exige acesso de leitura ao state
inteiro, segredos inclusos). Prefira `data "hcloud_network" ...` ou um parâmetro no cofre.

## 6. Bootstrap do state

O bucket/backend do state não pode ser criado pela própria raiz que o usa (ovo e galinha). Crie-o
numa raiz `bootstrap/` com **state local descartável ou migrado** e proteja o bucket (versionamento,
bloqueio de acesso público, `prevent_destroy`, acesso mínimo). Documente o procedimento em runbook
(`schematize-docs → runbook`); é a primeira coisa que alguém precisa quando tudo cai.

## 7. Terragrunt, Terramate e afins

Não são default. Entram por ADR quando o número de raízes torna a repetição de `backend.tf` e
`versions.tf` um custo real (dezenas de stacks). Antes disso, repetição explícita e revisável
vence abstração.

## 8. Nomes e tags

`snake_case` em recurso, variável e output (o `tflint` cobra). Nome de recurso descreve o
**papel**, não o tipo (`aws_db_instance.principal`, não `.db`). Tags/labels obrigatórias em tudo
que aceita (`env`, `owner`, `project`, `managed_by`) — a política `assets/policy/plano.rego`
reprova o plan sem elas.
