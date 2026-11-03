#!/usr/bin/env bash
# herdado: cópia de schematize-engineering/scripts/check-ci-triggers.sh (piso 27); não edite aqui, ressincronize da fonte.
# check-ci-triggers.sh — gate do piso 27 (CI remoto NÃO roda por commit, nem por PR; o gate por commit é local).
# O quê: lê workflows do GitHub Actions e REPROVA, no bloco `on:` (forma bloco, lista, flow `[a, b]`/`{a: {..}}`,
#   escalar `on: push`, aspas e multilinha): (a) `pull_request`/`pull_request_target` em QUALQUER forma
#   (com branches/paths/types ou sem); (b) `push` sem `tags:` positivo, ou com `branches`/`branches-ignore`
#   (`tags-ignore`/`branches-ignore` sozinhos abrem todas as branches); (c) `workflow_run`, `merge_group` e
#   qualquer evento fora da allowlist (permitidos: workflow_dispatch, workflow_call, repository_dispatch,
#   release, push de tags, schedule justificado); (d) `schedule` sem comentário `justificativa:` no arquivo;
#   (e) âncoras/aliases/merge-key (`&x`, `*x`, `<<:`) no bloco `on:` (não verificável); (f) workflow sem
#   `concurrency` com `cancel-in-progress: true`. AVISO (não reprova): push de tags sem `paths-ignore`.
# EXCEÇÃO LEGÍTIMA: arquivo `ci-triggers-allow.txt` (ao lado dos workflows ou em `.github/`), versionado, uma
#   linha por exceção: `<workflow.yml> <evento> justificativa: <texto >= 8 caracteres>`. Sem justificativa = ignorada.
# Uso: bash scripts/check-ci-triggers.sh [dir|arquivo.yml ...]   (default: .; procura .github/workflows/*.y*ml)
# Saída: exit 0 limpo, 1 achado, 2 uso inválido.
# LIMITAÇÃO (heurística, sem parser YAML completo): `on` gerado por template/include externo passa despercebido.
# strict-ok: gate acumula achados e sai no fim (`schematize-shell` -> `references/piso.md` secao 1)
set -uo pipefail
[ $# -gt 0 ] || set -- .
files=()
for a in "$@"; do
  if [ -f "$a" ]; then files+=("$a")
  elif [ -d "$a/.github/workflows" ]; then while IFS= read -r f; do files+=("$f"); done < <(find "$a/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)
  elif [ -d "$a" ]; then while IFS= read -r f; do files+=("$f"); done < <(find "$a" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)
  else echo "uso: check-ci-triggers.sh [dir|arquivo.yml ...]" >&2; exit 2; fi
done
[ "${#files[@]}" -gt 0 ] || { echo "check-ci-triggers: nenhum workflow encontrado (nada a checar)"; exit 0; }

# Extrai os eventos do bloco on: => linhas `EV|nome|tags|branches|paths`, `ANCHOR`, `NOON`, `CONC`/`NOCONC`.
extrai() {
  awk '
    function ind(s) { match(s, /^ */); return RLENGTH }
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function unq(s) { s = trim(s); gsub(/^["\x27]|["\x27]$/, "", s); return s }
    function ev(nome, sub_,   t, b, p) {
      t = (sub_ ~ /(^|[^A-Za-z_-])tags[ \t]*:/) ? 1 : 0
      b = (sub_ ~ /(^|[^A-Za-z_-])branches(-ignore)?[ \t]*:/ || sub_ ~ /branches-ignore/) ? 1 : 0
      p = (sub_ ~ /paths(-ignore)?[ \t]*:/) ? 1 : 0
      print "EV|" unq(nome) "|" t "|" b "|" p
    }
    function flow(s,   i, c, d, seg, n, q, k, nm, rs) {
      gsub(/\n/, " ", s); s = trim(s); d = 0; seg = ""; q = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (q != "") { seg = seg c; if (c == q) q = ""; continue }
        if (c == "\"" || c == "\x27") { q = c; seg = seg c; continue }
        if (c == "[" || c == "{") { d++; if (d > 1) seg = seg c; continue }
        if (c == "]" || c == "}") { d--; if (d >= 1) seg = seg c; if (d == 0) break; continue }
        if (c == "," && d == 1) { emite(seg); seg = ""; continue }
        seg = seg c
      }
      emite(seg)
    }
    function emite(seg,   k, nm, rs) {
      seg = trim(seg); if (seg == "") return
      k = index(seg, ":")
      if (k > 0) { nm = substr(seg, 1, k - 1); rs = substr(seg, k + 1) } else { nm = seg; rs = "" }
      ev(nm, rs)
    }
    { l = $0; sub(/(^|[ \t])#.*$/, "", l) }
    l ~ /^[ \t]*$/ { next }
    l ~ /^concurrency:/ { conc = 1 }
    l ~ /cancel-in-progress:[ \t]*true/ { cancel = 1 }
    inon && ind(l) == 0 && l !~ /^-/ { fimon() }
    l ~ /^("on"|\x27on\x27|on):/ {
      inon = 1; achou = 1; rest = l; sub(/^("on"|\x27on\x27|on):[ \t]*/, "", rest); txt = rest; nl = 0; next
    }
    inon { nl++; ln[nl] = l; txt = txt "\n" l }
    function fimon(   i, first, base, key, subb, k, f1, cur, curb) {
      inon = 0
      if (txt ~ /(^|[:\-\[,{ \t])[&*][A-Za-z_][A-Za-z0-9_-]*([ \t,}\]]|$)/ || txt ~ /<<[ \t]*:/) print "ANCHOR"
      first = trim(rest)
      if (first == "") { for (i = 1; i <= nl; i++) { if (trim(ln[i]) != "") { first = trim(ln[i]); break } } }
      if (substr(first, 1, 1) == "[" || substr(first, 1, 1) == "{") { flow(txt); return }
      if (trim(rest) != "") { ev(rest, ""); return }   # escalar: on: push
      base = -1; cur = ""; curb = ""
      for (i = 1; i <= nl; i++) {
        if (base < 0) base = ind(ln[i])
        if (ind(ln[i]) == base) {
          if (cur != "") ev(cur, curb)
          f1 = trim(ln[i])
          if (substr(f1, 1, 2) == "- ") { ev(substr(f1, 3), ""); cur = ""; curb = ""; continue }
          k = index(f1, ":")
          if (k > 0) { cur = substr(f1, 1, k - 1); curb = substr(f1, k + 1) } else { cur = f1; curb = "" }
        } else curb = curb "\n" ln[i]
      }
      if (cur != "") ev(cur, curb)
    }
    END { if (inon) fimon(); if (!achou) print "NOON"; print (conc && cancel) ? "CONCOK" : "NOCONC" }
  ' "$1"
}

allowed() { # arquivo evento -> 0 se há exceção justificada versionada
  local f="$1" ev="$2" base d al
  base="$(basename "$f")"; d="$(dirname "$f")"
  for al in "${CI_TRIGGERS_ALLOW:-}" "$d/ci-triggers-allow.txt" "$d/../ci-triggers-allow.txt"; do
    [ -n "$al" ] && [ -f "$al" ] || continue
    while read -r wf evt kw just; do
      [ "$wf" = "$base" ] && [ "$evt" = "$ev" ] && [ "$kw" = "justificativa:" ] && [ "${#just}" -ge 8 ] && return 0
    done < "$al"
  done
  return 1
}

rc=0
for f in "${files[@]}"; do
  out=""; add() { out="$out$1"$'\n'; }
  while IFS='|' read -r kind nome tags br paths; do
    case "$kind" in
      ANCHOR) add "FAIL: âncora/alias/merge-key no bloco on: — não verificável; escreva os gatilhos por extenso (piso 27)" ;;
      NOON) add "AVISO: sem bloco on: (não é workflow?)" ;;
      NOCONC) add "FAIL: sem concurrency com cancel-in-progress: true — piso 27" ;;
      EV)
        case "$nome" in
          workflow_dispatch|workflow_call|repository_dispatch|release) ;;
          push)
            if allowed "$f" push; then add "AVISO: push em branch liberado por ci-triggers-allow.txt"
            elif [ "$tags" != 1 ] || [ "$br" = 1 ]; then add "FAIL: on: push em branch (sem tags: positivo, ou com branches/branches-ignore/tags-ignore) — piso 27: use workflow_dispatch + push: tags [hml-*, v*]"
            elif [ "$paths" != 1 ]; then add "AVISO: push de tags sem paths-ignore (docs/md)"; fi ;;
          schedule)
            grep -qi 'justificativa:' "$f" || allowed "$f" schedule || add "FAIL: schedule (cron) sem comentário 'justificativa:' — piso 27" ;;
          pull_request|pull_request_target|workflow_run|merge_group)
            allowed "$f" "$nome" && add "AVISO: $nome liberado por ci-triggers-allow.txt" || add "FAIL: $nome (qualquer filtro) roda CI por commit/PR — VETADO pelo piso 27; use workflow_dispatch + tags hml-*/v*" ;;
          *) allowed "$f" "$nome" && add "AVISO: $nome liberado por ci-triggers-allow.txt" || add "FAIL: evento '$nome' fora da allowlist do piso 27 (workflow_dispatch, workflow_call, repository_dispatch, release, push de tags, schedule justificado)" ;;
        esac ;;
    esac
  done < <(extrai "$f")
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "$f: $line"
    case "$line" in FAIL*) rc=1 ;; esac
  done <<<"$out"
done
[ "$rc" -eq 0 ] && echo "check-ci-triggers: OK (${#files[@]} workflow(s))"
exit "$rc"
