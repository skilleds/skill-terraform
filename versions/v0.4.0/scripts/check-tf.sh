#!/usr/bin/env bash
# check-tf.sh — gate estático da schematize-terraform. Funciona SEM terraform/tofu instalado.
#
# Motivo: o que mais machuca em IaC (state local, provider solto, segredo no tfvars, recurso
# de dados que some por mudança de índice) é visível no texto do repo, antes de qualquer plan.
# Como funciona: percorre os diretórios com *.tf, classifica cada um como RAIZ (envs/, stacks/…)
# ou MÓDULO (caminho com /modules/) e aplica as regras abaixo com awk (sem parser HCL: heurística
# de blocos de topo; o que ela não prova, o tflint/validate provam).
# Entrada: $1 = diretório (default .). Env: TF_GATE_TEXTO=1 desliga cor (já é sem cor).
# Saída: achados `arquivo:linha: [ERRO|AVISO regra] mensagem`.
#        exit 0 passa · 1 reprova · 2 NADA para verificar (não é aprovação).
#
# Ferramenta: OpenTofu e Terraform têm paridade. O gate DETECTA qual o repo usa (lock file/registry,
#   *.tofu e *.tofutest.hcl, bloco encryption{}, workflow, `# tf-tool: tofu|terraform` ou TF_GATE_TOOL)
#   e aplica as regras do ramo certo. Sinais dos dois lados no mesmo repo = ferramenta-mista.
#
# Regras (id): ferramenta-mista · ferramenta-indefinida · tofu-sem-criptografia ·
#   tofu-criptografia-sem-enforced · terraform-state-sem-kms · backend-ausente · backend-local · required-version · provider-sem-pin ·
#   provider-sem-teto · lock-ausente · lock-sem-multiplataforma · segredo-literal ·
#   state-versionado · critico-sem-prevent-destroy · provider-em-modulo · variavel-sensivel ·
#   output-sensivel · ci-gatilho (delega ao check-ci-triggers.sh: push de branch, pull_request, cron sem justificativa, sem concurrency cancel true).
# Ramo OpenTofu: raiz com backend exige terraform { encryption { ... state { enforced = true } } }.
# Ramo Terraform: backend s3 exige encrypt = true + kms_key_id; gcs exige kms_encryption_key.
# Waiver rastreável: `# tf-ok: <motivo>` na linha ou na de cima (regras de linha/bloco);
#   `# tf-ok: <regra-id> <motivo>` em qualquer .tf do diretório (regras de diretório).
set -euo pipefail

RAIZ="${1:-.}"
[ -d "$RAIZ" ] || { echo "check-tf: '$RAIZ' não é diretório" >&2; exit 2; }

ACHADOS="$(mktemp)"
trap 'rm -f "$ACHADOS"' EXIT INT TERM
: >"$ACHADOS"

emit() { # emit <arquivo> <linha> <ERRO|AVISO> <regra> <msg>
  printf '%s:%s: [%s %s] %s\n' "$1" "$2" "$3" "$4" "$5" >>"$ACHADOS"
}

# Programa awk por arquivo .tf: blocos de topo + regras de linha.
# Variáveis: -v arq= -v modulo=0|1. Emite achados em stdout e linhas META para o agregador.
AWK_TF='
function strip(s) { gsub(/"([^"\\]|\\.)*"/, "\"\"", s); return s }
function nc(s,   t) { t = s; sub(/^[ \t]*(#|\/\/).*$/, "", t); return t }
function waived(l, p) { return (l ~ /tf[-]ok:/ || p ~ /tf[-]ok:/) }
function meta(k) { printf "META\t%s\t%s\n", k, arq }
function out(sev, rule, ln, msg) { printf "%s:%d: [%s %s] %s\n", arq, ln, sev, rule, msg }
function nome_sensivel(n) { return (n ~ /(password|passwd|secret|token|api_key|apikey|private_key|credential|passphrase|secret_key|access_key)s?$/) }
function critico(t) {
  return (t ~ /^(aws_db_instance|aws_rds_cluster|aws_s3_bucket|aws_dynamodb_table|aws_kms_key|aws_ebs_volume|aws_efs_file_system|hcloud_volume|hcloud_primary_ip|hcloud_floating_ip|cloudflare_zone|cloudflare_r2_bucket|google_sql_database_instance|google_storage_bucket|azurerm_mssql_database|azurerm_storage_account|azurerm_key_vault|github_repository)$/)
}
function fecha_bloco(   i, n, linhas, l, rp, depth2, pname, pbody, pstart, ptxt) {
  if (btype == "variable" && nome_sensivel(bl1)) {
    if (!bsens && !waived(bhdr, bprev)) out("ERRO", "variavel-sensivel", bstart, "variable \"" bl1 "\" parece segredo e não tem sensitive = true (nem ephemeral = true)")
    if (bdefault_lit && !waived(bhdr, bprev)) out("ERRO", "segredo-literal", bstart, "variable \"" bl1 "\" tem default literal: segredo nunca em código")
  }
  if (btype == "output" && nome_sensivel(bl1)) {
    if (!bsens && !waived(bhdr, bprev)) out("ERRO", "output-sensivel", bstart, "output \"" bl1 "\" parece segredo e não tem sensitive = true (nem ephemeral = true)")
  }
  if (btype == "provider" && modulo == 1) {
    if (!waived(bhdr, bprev)) out("ERRO", "provider-em-modulo", bstart, "provider \"" bl1 "\" configurado dentro de módulo filho: a raiz configura, o módulo só declara required_providers")
  }
  if (btype == "resource" && critico(bl1)) {
    if (!bprevent && !waived(bhdr, bprev)) {
      if (bmulti) out("ERRO", "critico-sem-prevent-destroy", bstart, "resource \"" bl1 "\" \"" bl2 "\" crítico com count/for_each e sem lifecycle { prevent_destroy = true } (mudar o índice destrói o dado)")
      else out("AVISO", "critico-sem-prevent-destroy", bstart, "resource \"" bl1 "\" \"" bl2 "\" crítico sem prevent_destroy")
    }
  }
  if (btype == "terraform") {
    meta("tem_terraform")
    if (btxt ~ /required_version[ \t]*=/) meta("required_version")
    sc = btxt; gsub(/(^|\n)[ \t]*(#|\/\/)[^\n]*/, "\n", sc)
    if (sc ~ /encryption[ \t]*\{/) meta("encryption")
    if (sc ~ /enforced[ \t]*=[ \t]*true/) meta("enforced")
    if (match(sc, /backend[ \t]+"[a-z0-9_]+"/)) { bt = substr(sc, RSTART, RLENGTH); sub(/^backend[ \t]+"/, "", bt); sub(/"$/, "", bt); meta("backend_tipo_" bt) }
    if (sc ~ /backend[ \t]+"[a-z0-9_]+"/ && sc ~ /encrypt[ \t]*=[ \t]*true/) meta("backend_encrypt")
    if (sc ~ /(kms_key_id|kms_encryption_key)[ \t]*=/) meta("backend_kms")
    if (btxt ~ /backend[ \t]+"local"/) meta("backend_local")
    else if (btxt ~ /backend[ \t]+"[a-z0-9_]+"/) meta("backend_remoto")
    if (btxt ~ /required_providers[ \t]*\{/) meta("required_providers")
    # required_providers: cada provider precisa de version; raiz exige teto
    n = split(btxt, linhas, "\n"); rp = 0; depth2 = 0; pname = ""
    for (i = 1; i <= n; i++) {
      l = nc(linhas[i]); ls = strip(l)
      if (rp == 0) { if (ls ~ /required_providers[ \t]*\{/) { rp = 1; depth2 = 0 } continue }
      if (depth2 == 0 && ls ~ /^[ \t]*[A-Za-z0-9_-]+[ \t]*=[ \t]*\{/) {
        pname = l; sub(/^[ \t]*/, "", pname); sub(/[ \t]*=.*/, "", pname); pbody = ""; pstart = bstart + i - 1; ptxt = ""
      } else if (depth2 == 0 && ls ~ /^[ \t]*[A-Za-z0-9_-]+[ \t]*=[ \t]*"/) {
        pname = l; sub(/^[ \t]*/, "", pname); sub(/[ \t]*=.*/, "", pname)
        if (!waived(linhas[i], linhas[i-1])) out("ERRO", "provider-sem-pin", bstart + i - 1, "provider \"" pname "\" na forma legada (string): use { source, version }")
      }
      if (pname != "" && depth2 >= 1) ptxt = ptxt "\n" l
      o = gsub(/\{/, "{", ls); c = gsub(/\}/, "}", ls); depth2 += o - c
      if (depth2 < 0) { rp = 0; continue }
      if (pname != "" && depth2 == 0 && ptxt != "") {
        if (ptxt !~ /version[ \t]*=/) { if (!waived(linhas[pstart - bstart + 1], linhas[pstart - bstart])) out("ERRO", "provider-sem-pin", pstart, "provider \"" pname "\" sem version em required_providers") }
        else if (modulo == 0) {
          v = ptxt; sub(/.*version[ \t]*=[ \t]*"/, "", v); sub(/".*/, "", v)
          if (v !~ /(~>|<)/ && v ~ />/) { if (!waived(linhas[pstart - bstart + 1], linhas[pstart - bstart])) out("ERRO", "provider-sem-teto", pstart, "provider \"" pname "\" com version \"" v "\" sem teto: na raiz use ~> ou intervalo fechado") }
        }
        pname = ""; ptxt = ""
      }
    }
  }
  if (btype == "provider" && modulo == 0) meta("provider_usado")
  if (btype == "resource" || btype == "module" || btype == "data") meta("provider_usado")
}
BEGIN { depth = 0; btype = "" }
{
  raw = $0
  # --- regra de linha: segredo literal (vale dentro e fora de bloco) ---
  lc = nc(raw)
  if (lc != "" && !waived(raw, prev)) {
    if (lc ~ /^[ \t]*[A-Za-z0-9_]*(password|passwd|secret|token|api_key|apikey|private_key|passphrase|secret_key|access_key|client_secret|secret_string|credentials?)[ \t]*=[ \t]*"[^"$]+"/) {
      out("ERRO", "segredo-literal", NR, "atributo de segredo com valor literal: use cofre/variável de ambiente/ephemeral, nunca texto no código")
    } else if (lc ~ /AKIA[0-9A-Z]{16}/ || lc ~ /-----BEGIN [A-Z ]*PRIVATE KEY-----/ || lc ~ /gh[pousr]_[A-Za-z0-9]{30,}/ || lc ~ /xox[abp]-[0-9A-Za-z-]{10,}/) {
      out("ERRO", "segredo-literal", NR, "credencial no formato de chave conhecida no texto")
    }
  }
  if (isvars) { prev = raw; next }
  s = strip(lc)
  if (depth == 0) {
    if (s ~ /^[ \t]*(resource|variable|output|provider|terraform|module|data|locals)[ \t]*("[^"]*"[ \t]*)*\{/) {
      btype = s; sub(/^[ \t]*/, "", btype); sub(/[ \t"{].*/, "", btype)
      bl1 = ""; bl2 = ""
      t = lc; q = split(t, partes, "\"")
      if (q >= 2) bl1 = partes[2]
      if (q >= 4) bl2 = partes[4]
      bstart = NR; bhdr = raw; bprev = prev; btxt = ""
      bsens = 0; bmulti = 0; bprevent = 0; bdefault_lit = 0
    }
  }
  if (btype != "") {
    btxt = btxt raw "\n"
    if (depth == 1) {
      if (lc ~ /^[ \t]*(count|for_each)[ \t]*=/) bmulti = 1
      if (lc ~ /^[ \t]*(sensitive|ephemeral)[ \t]*=[ \t]*true/) bsens = 1
      if (btype == "variable" && lc ~ /^[ \t]*default[ \t]*=[ \t]*"[^"$]+"/) bdefault_lit = 1
    }
    if (lc ~ /prevent_destroy[ \t]*=[ \t]*true/) bprevent = 1
    o = gsub(/\{/, "{", s); c = gsub(/\}/, "}", s)
    depth += o - c
    if (depth <= 0) { depth = 0; fecha_bloco(); btype = "" }
  }
  prev = raw
}
'

# --- coleta de arquivos -------------------------------------------------------------
LISTA="$(mktemp)"
trap 'rm -f "$ACHADOS" "$LISTA"' EXIT INT TERM
find "$RAIZ" \( -name .git -o -name .terraform -o -name node_modules -o -name versions \) -prune -o \
  -type f \( -name '*.tf' -o -name '*.tofu' -o -name '*.tfvars' \) -print | LC_ALL=C sort >"$LISTA"

if [ ! -s "$LISTA" ]; then
  echo "check-tf: nenhum .tf/.tofu/.tfvars em '$RAIZ' — nada para verificar (exit 2, não é aprovação)" >&2
  exit 2
fi

eh_modulo() { case "/$1/" in */modules/*) return 0 ;; *) return 1 ;; esac }

# --- por diretório ------------------------------------------------------------------
DIRS="$(while IFS= read -r f; do case "$f" in *.tf|*.tofu) dirname "$f" ;; esac; done <"$LISTA" | LC_ALL=C sort -u)"

dir_waived() { # dir_waived <dir> <regra>
  local d="$1" r="$2" f
  for f in "$d"/*.tf "$d"/*.tofu; do
    [ -e "$f" ] || continue
    grep -qE "tf-ok:[[:space:]]*$r([[:space:]]|\$)" "$f" && return 0
  done
  return 1
}

# Pass 1: awk por arquivo (achados de bloco/linha + META por diretório)
while IFS= read -r f; do
  d="$(dirname "$f")"
  mod=0; eh_modulo "$d" && mod=1
  isv=0; case "$f" in *.tfvars) isv=1 ;; esac
  awk -v arq="$f" -v modulo="$mod" -v isvars="$isv" "$AWK_TF" "$f" >>"$ACHADOS.raw.$$" 2>/dev/null || true
done <"$LISTA"
trap 'rm -f "$ACHADOS" "$LISTA" "$ACHADOS.raw.$$"' EXIT INT TERM
[ -e "$ACHADOS.raw.$$" ] || : >"$ACHADOS.raw.$$"
grep -v $'^META\t' "$ACHADOS.raw.$$" >>"$ACHADOS" || true

# Pass 2: regras de diretório (precisam do agregado de META por arquivo).
meta_dir() { # meta_dir <dir> <chave> -> 0 se algum .tf do dir emitiu a chave
  awk -F'\t' -v d="$1" -v k="$2" '
    $1 == "META" && $2 == k { f = $3; sub(/\/[^\/]*$/, "", f); if (f == d) achou = 1 }
    END { exit !achou }' "$ACHADOS.raw.$$"
}

# --- ferramenta: detecta OpenTofu x Terraform e confere a unicidade ----------------------------
EV_TOFU=(); EV_TF=()
while IFS= read -r l; do
  [ -n "$l" ] || continue
  if grep -q 'registry\.opentofu\.org/' "$l"; then EV_TOFU+=("$l (registry.opentofu.org)"); fi
  if grep -q 'registry\.terraform\.io/' "$l"; then EV_TF+=("$l (registry.terraform.io)"); fi
done < <(find "$RAIZ" \( -name .git -o -name .terraform -o -name node_modules -o -name versions \) -prune -o -type f -name .terraform.lock.hcl -print | LC_ALL=C sort)
while IFS= read -r l; do
  [ -n "$l" ] && EV_TOFU+=("$l (arquivo exclusivo do OpenTofu)")
done < <(find "$RAIZ" \( -name .git -o -name .terraform -o -name node_modules -o -name versions \) -prune -o -type f \( -name '*.tofu' -o -name '*.tofutest.hcl' \) -print | LC_ALL=C sort)
enc="$(awk -F'\t' '$1 == "META" && $2 == "encryption" { print $3; exit }' "$ACHADOS.raw.$$")"
[ -z "$enc" ] || EV_TOFU+=("$enc (bloco encryption{}: só existe no OpenTofu)")
decl="$(printf '%s\n' "${TF_GATE_TOOL:-}" | grep -E '^(tofu|opentofu|terraform)$' || true)"
if [ -n "$decl" ]; then
  case "$decl" in terraform) EV_TF+=("TF_GATE_TOOL=terraform") ;; *) EV_TOFU+=("TF_GATE_TOOL=$decl") ;; esac
fi
while IFS=: read -r arq _ nome; do
  [ -n "$arq" ] || continue
  case "$nome" in terraform) EV_TF+=("$arq (# tf-tool: terraform)") ;; *) EV_TOFU+=("$arq (# tf-tool: $nome)") ;; esac
done < <(grep -rEoH --include='*.tf' --include='*.tofu' 'tf-tool:[[:space:]]*(tofu|opentofu|terraform)' "$RAIZ" 2>/dev/null | sed -E 's/tf-tool:[[:space:]]*/x:/' | LC_ALL=C sort -u || true)
# workflows de CI (no RAIZ e na raiz do repo git)
WFD="$RAIZ/.github/workflows"
if TOPO_WF="$(git -C "$RAIZ" rev-parse --show-toplevel 2>/dev/null)"; then WFD="$WFD $TOPO_WF/.github/workflows"; fi
for wd in $WFD; do
  [ -d "$wd" ] || continue
  for wf in "$wd"/*.yml "$wd"/*.yaml; do
    [ -e "$wf" ] || continue
    txt="$(grep -vE '^[[:space:]]*#' "$wf" || true)"
    pt="$(grep -oE '^[[:space:]]*TF_TOOL:[[:space:]]*"?(tofu|terraform)' <<<"$txt" | head -1 | sed -E 's/.*(tofu|terraform)$/\1/' || true)"
    if [ -n "$pt" ]; then
      if [ "$pt" = tofu ]; then EV_TOFU+=("$wf (TF_TOOL: tofu)"); else EV_TF+=("$wf (TF_TOOL: terraform)"); fi
    else
      if grep -qE 'setup-opentofu|(^|[^A-Za-z0-9_-])tofu[[:space:]]+(init|plan|apply|validate|fmt|test|show|providers)' <<<"$txt"; then EV_TOFU+=("$wf (workflow usa tofu)"); fi
      if grep -qE 'setup-terraform|(^|[^A-Za-z0-9_-])terraform[[:space:]]+(init|plan|apply|validate|fmt|test|show|providers)' <<<"$txt"; then EV_TF+=("$wf (workflow usa terraform)"); fi
    fi
  done
done

# --- gatilhos do CI (piso 27): workflow não roda por commit/PR, nem aplica em push de branch -----------
# Delega ao check-ci-triggers.sh (cópia herdada da engineering, ao lado deste script). Cada FAIL vira ERRO.
CITRIG="$(dirname "${BASH_SOURCE[0]}")/check-ci-triggers.sh"
for wd in $WFD; do
  [ -d "$wd" ] || continue
  if [ ! -f "$CITRIG" ]; then
    emit "$wd" 1 AVISO ci-gatilho "check-ci-triggers.sh ausente ao lado do gate: gatilhos do CI não verificados (piso 27)"
    break
  fi
  while IFS= read -r l; do
    case "$l" in
      *": FAIL: "*) emit "${l%%: FAIL: *}" 1 ERRO ci-gatilho "${l#*: FAIL: }" ;;
    esac
  done < <(bash "$CITRIG" "$wd" 2>&1 || true)
done

FERR=""
if [ "${#EV_TOFU[@]}" -gt 0 ] && [ "${#EV_TF[@]}" -gt 0 ]; then
  mista_ok=0
  while IFS= read -r d; do [ -n "$d" ] && dir_waived "$d" ferramenta-mista && mista_ok=1; done <<<"$DIRS"
  if [ "$mista_ok" = 0 ]; then
    emit "$RAIZ" 1 ERRO ferramenta-mista "sinais de OpenTofu E de Terraform no mesmo repo (uma ferramenta por repo; o lock carrega o registry). OpenTofu: ${EV_TOFU[0]}; Terraform: ${EV_TF[0]}"
  fi
elif [ "${#EV_TOFU[@]}" -gt 0 ]; then FERR=tofu
elif [ "${#EV_TF[@]}" -gt 0 ]; then FERR=terraform
else
  emit "$RAIZ" 1 AVISO ferramenta-indefinida "não deu para detectar a ferramenta (sem lock, *.tofu, workflow, TF_TOOL ou '# tf-tool: tofu|terraform'): as regras de state por ferramenta foram puladas"
fi

while IFS= read -r d; do
  [ -n "$d" ] || continue
  mod=0; eh_modulo "$d" && mod=1
  meta_dir "$d" provider_usado || meta_dir "$d" tem_terraform || continue   # diretório só de variáveis/locals: ignora
  if [ "$mod" = 0 ]; then
    if ! meta_dir "$d" backend_remoto && ! meta_dir "$d" backend_local; then
      dir_waived "$d" backend-ausente || emit "$d" 1 ERRO backend-ausente "raiz sem bloco backend: o state ficaria LOCAL (sem lock, sem backup, sem time). Declare backend remoto com lock"
    fi
    if meta_dir "$d" backend_local; then
      dir_waived "$d" backend-local || {
        linha="$(grep -n 'backend[[:space:]]*"local"' "$d"/*.tf "$d"/*.tofu 2>/dev/null | head -1 | cut -d: -f1-2 || true)"
        emit "$d" "${linha:-1}" ERRO backend-local "backend \"local\" em código de ambiente: state em disco de laptop/CI não tem lock nem time"
      }
    fi
  fi
  if [ "$mod" = 0 ]; then
    if meta_dir "$d" backend_remoto && [ "$FERR" = tofu ]; then
      if ! meta_dir "$d" encryption; then
        dir_waived "$d" tofu-sem-criptografia || emit "$d" 1 ERRO tofu-sem-criptografia "OpenTofu com backend remoto e sem terraform { encryption { ... } }: state/plan em claro no backend. Declare key_provider + method e state/plan { enforced = true } (chave via TF_ENCRYPTION no CI: waiver com motivo)"
      elif ! meta_dir "$d" enforced; then
        dir_waived "$d" tofu-criptografia-sem-enforced || emit "$d" 1 ERRO tofu-criptografia-sem-enforced "encryption{} sem enforced = true: o OpenTofu aceitaria ler/gravar state em claro"
      fi
    fi
    if meta_dir "$d" backend_remoto && [ "$FERR" = terraform ]; then
      if meta_dir "$d" backend_tipo_s3 && { ! meta_dir "$d" backend_encrypt || ! meta_dir "$d" backend_kms; }; then
        dir_waived "$d" terraform-state-sem-kms || emit "$d" 1 ERRO terraform-state-sem-kms "Terraform sem criptografia nativa de state: backend s3 exige encrypt = true E kms_key_id (SSE-KMS), com acesso restrito à chave. S3-compatível sem KMS: waiver com motivo"
      elif meta_dir "$d" backend_tipo_gcs && ! meta_dir "$d" backend_kms; then
        dir_waived "$d" terraform-state-sem-kms || emit "$d" 1 ERRO terraform-state-sem-kms "backend gcs sem kms_encryption_key (CMEK): Terraform não cifra o state no cliente"
      elif ! meta_dir "$d" backend_tipo_s3 && ! meta_dir "$d" backend_tipo_gcs && ! meta_dir "$d" backend_tipo_azurerm && ! meta_dir "$d" backend_tipo_cloud && ! meta_dir "$d" backend_tipo_remote; then
        emit "$d" 1 AVISO terraform-state-sem-kms "backend de tipo não verificado pelo gate: confirme criptografia server-side com chave gerenciada e acesso restrito"
      fi
    fi
  fi
  if ! meta_dir "$d" required_version; then
    dir_waived "$d" required-version || emit "$d" 1 ERRO required-version "sem required_version no bloco terraform {} (versão da CLI não fixada)"
  fi
  if ! meta_dir "$d" required_providers; then
    dir_waived "$d" provider-sem-pin || emit "$d" 1 ERRO provider-sem-pin "sem required_providers com version (provider solto sobe sem aviso)"
  fi
  if [ "$mod" = 0 ] && meta_dir "$d" required_providers; then
    lock="$d/.terraform.lock.hcl"
    if [ ! -f "$lock" ]; then
      dir_waived "$d" lock-ausente || emit "$d" 1 ERRO lock-ausente ".terraform.lock.hcl ausente: commite-o (reprodutibilidade e supply chain dos providers)"
    else
      # >= 2 hashes h1: por provider = lock multiplataforma (providers lock -platform=...)
      awk -v arq="$lock" '
        /^provider "/ { if (nome != "" && h1 < 2) printf "%s:%d: [ERRO lock-sem-multiplataforma] provider %s com %d hash h1 (rode providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_arm64 -platform=darwin_amd64 -platform=windows_amd64)\n", arq, ln, nome, h1; nome=$2; gsub(/"/, "", nome); h1=0; ln=NR }
        /"h1:/ { h1++ }
        END { if (nome != "" && h1 < 2) printf "%s:%d: [ERRO lock-sem-multiplataforma] provider %s com %d hash h1 (rode providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_arm64 -platform=darwin_amd64 -platform=windows_amd64)\n", arq, ln, nome, h1 }
      ' "$lock" >>"$ACHADOS"
    fi
  fi
done <<<"$DIRS"

# --- state / plan versionado ------------------------------------------------------------
# Em repo git usa o índice (o que está VERSIONADO); fora de git, o que existe na árvore.
if git -C "$RAIZ" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TOPO="$(git -C "$RAIZ" rev-parse --show-toplevel)"
  ARQS="$(git -C "$RAIZ" ls-files -- '*.tfstate' '*.tfstate.*' '*.tfplan' 'tfplan' 'tfplan.json' 2>/dev/null | sed "s|^|$TOPO/|" || true)"
else
  ARQS="$(find "$RAIZ" \( -name .git -o -name .terraform \) -prune -o -type f \( -name '*.tfstate' -o -name '*.tfstate.*' -o -name '*.tfplan' -o -name tfplan -o -name tfplan.json \) -print)"
fi
if [ -n "$ARQS" ]; then
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    emit "$a" 1 ERRO state-versionado "state/plan no repositório: contém segredo em claro. Remova do histórico, rotacione o que vazou, e ponha no .gitignore"
  done <<<"$ARQS"
fi

# --- relatório ---------------------------------------------------------------------------
ERROS="$(grep -c '\[ERRO ' "$ACHADOS" || true)"
AVISOS="$(grep -c '\[AVISO ' "$ACHADOS" || true)"
if [ -s "$ACHADOS" ]; then LC_ALL=C sort -u "$ACHADOS"; fi
if [ "$ERROS" -gt 0 ]; then
  echo "check-tf: REPROVADO — $ERROS erro(s), $AVISOS aviso(s)." >&2
  veredito=1
else
  echo "check-tf: no piso — 0 erro(s), $AVISOS aviso(s)."
  veredito=0
fi
exit "$veredito"
