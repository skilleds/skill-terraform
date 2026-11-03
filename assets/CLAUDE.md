# Piso de IaC (schematize-terraform) — sempre-on

IaC é código de produção com a credencial de produção. O state é a memória; o plan é o contrato.

1. **OpenTofu e Terraform em paridade (sem default, sem ADR obrigatório); UMA por repo**, nunca misturar (o lock carrega o registry). Escolha registrada no README/ADR do projeto. Exemplos: `$TF` = `tofu` ou `terraform`.
2. **Raiz por ambiente (`envs/hml`, `envs/prd`) + `modules/`.** Nunca `workspace` para separar hml
   de prd (mesmo backend, mesma credencial, estado oculto).
3. **State remoto, com lock, versionado e criptografado**, um por ambiente e por stack. Em claro é
   vetado: OpenTofu com `encryption { enforced = true }`; Terraform com backend server-side + KMS e
   acesso restrito. Sem backend local em código de ambiente. Nunca `*.tfstate`/`*.tfplan` no git.
4. **`required_version` + `required_providers` com `version`** (raiz: `~>`); **`.terraform.lock.hcl`
   commitado**, com hashes de todas as plataformas (`providers lock -platform=...`).
5. **Módulo é API:** `type` + `description` + `validation`; saída mínima; segredo `sensitive`;
   **nunca `provider {}` em módulo filho**; `for_each` com chave estável, não `count` sobre estado.
6. **Segredo nunca em `.tf`, `.tfvars` ou `default`.** Prefira `ephemeral` + `*_wo` ou cofre lido
   em runtime; o que entrar no state, com state cifrado. `sensitive` só esconde do terminal.
7. **plan salvo -> revisão humana -> apply só desse plan** (artefato da mesma execução do CI). Apply de prd só
   pelo CI, em *environment* protegido. **Nunca `apply` local em prd. Nunca `-auto-approve` fora de efêmero.**
   **A IA nunca roda `apply`/`destroy`/`state *` local (nem em hml): pede a operação nomeada ao ops.** CI só em
   `workflow_dispatch` + tags `hml-*`/`v*`; nunca apply em push de branch (piso 27).
8. **Dado leva `prevent_destroy`** + proteção do provedor. Leia todo `destroy`/`replace` do plan.
9. **`moved`/`import`/`removed`**, nunca `state mv/rm` à mão. `-target` só em emergência registrada.
10. **Drift**: plan sob demanda (cron só com `# justificativa:`), credencial somente leitura; resolve-se por commit no git.
11. **Tags/labels obrigatórias** (`env`, `owner`, `project`, `managed_by`).
12. **Degraus que travam a promoção:** `fmt`, `validate`, `check-tf.sh` (inclui gatilhos de CI), `tflint`, `checkov`/`trivy`,
    `$TF test`, `conftest`; por commit, local. Exceção só com motivo escrito.
13. Efeito externo (e-mail, webhook, DNS de envio) nunca sai de não-produção.
14. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

Herda os pisos 22–29 da `schematize-engineering` (git como trava de conclusão, deploy só do git, ops é o gate da IA, sem agents inúteis, relatório 30 min/handoff 6 h, CI remoto só antes do hml, microserviço autônomo, build em dev/hml + higiene).

Mídia: imagem/visual gerado nunca por modelo Claude; detecte Codex/Gemini e pergunte qual usar.

Gate: `bash .claude/skills/schematize-terraform/scripts/check-tf.sh .` — waiver rastreável
`# tf-ok: <motivo>`.
