#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# Instalador SDKMAN com candidato genérico (-c) + progresso
# - default candidate: java
# - progresso [done/total %]
# - parsing por colunas '|' com FALLBACK por "Identifier"
# - blindado p/ set -u; PAGER/LESS/GIT_PAGER seguros; LC_ALL=C
# =========================================================

# -------------------------
# Defaults / opções
# -------------------------
CANDIDATE="java"       # -c|--candidate (java, maven, gradle, etc.)
VENDORS_INCLUDE=()     # -V "temurin,oracle" (apenas p/ java)
VENDORS_EXCLUDE=()     # -X "open,zulu"      (apenas p/ java)
MATCH_REGEX=""         # -M '^17\.'
ONLY_LTS=false         # -L                  (apenas p/ java)
LATEST_ONLY=false      # -T
INCLUDE_EA=false       # -E                  (apenas p/ java)
PARALLEL=1             # -p N
DRY_RUN=false          # -n
AUTO_YES=false         # -y
MAX_PER_VENDOR=0       # -m N                (apenas p/ java)
LIST_ONLY=false        # -l
REINSTALL=false        # -r
KEEP_GOING=true        # -k / -K
SELFTEST=false         # --selftest
DEBUG_LOG=false        # --debug

# -------------------------
# Ajuda
# -------------------------
usage() {
  cat <<'EOF'
Instala versões de um candidato do SDKMAN (default: java), com filtros, paralelismo, barra de progresso
e parsing robusto (com fallback) da listagem do SDKMAN.

Uso:
  install-sdk.sh [opções]

Candidato:
  -c NAME          --candidate NAME     Candidato (default: java). Ex.: java, maven, gradle, scala, etc.

Filtros (gerais):
  -M REGEX         --match REGEX        Regex nas versões/identifiers (ex.: '^17\.')
  -T               --latest-only        Somente a mais recente
  -p N             --parallel N         Paralelizar instalações
  -n               --dry-run            Só mostrar o que faria
  -y               --yes                Aceitar prompts do SDKMAN
  -l               --list-only          Apenas listar (não instala)
  -r               --reinstall          Reinstalar (uninstall -> install)
  -k               --keep-going         Continuar se falhar (padrão)
  -K               --no-keep-going      Parar no primeiro erro

Filtros específicos p/ JAVA:
  -V "v1,v2,..."   --vendors "v1,v2,..."  Limitar vendors (temurin, zulu, oracle, graalce, open, sapmachine, etc.)
  -X "v1,v2,..."   --exclude "v1,v2,..."  Excluir vendors
  -L               --lts-only             Apenas LTS (8,11,17,21,25)
  -E               --include-ea           Incluir EA (Early Access)
  -m N             --max-per-vendor N     Limitar N versões por vendor

Utilidades:
  --selftest                             Diagnóstico do ambiente e saída
  --debug                                Salva saídas brutas do 'sdk list' em /tmp
  -h               --help                Ajuda
EOF
}

# -------------------------
# Parse de argumentos
# -------------------------
args=("$@")
i=0
while [[ $i -lt $# ]]; do
  case "${args[$i]}" in
    -h|--help) usage; exit 0 ;;
    --selftest) SELFTEST=true ;;
    --debug) DEBUG_LOG=true ;;
    -c|--candidate) ((i++)); CANDIDATE="${args[$i]:-java}" ;;
    -V|--vendors) ((i++)); IFS=',' read -r -a VENDORS_INCLUDE <<< "${args[$i]:-}" ;;
    -X|--exclude) ((i++)); IFS=',' read -r -a VENDORS_EXCLUDE <<< "${args[$i]:-}" ;;
    -M|--match) ((i++)); MATCH_REGEX="${args[$i]:-}" ;;
    -L|--lts-only) ONLY_LTS=true ;;
    -T|--latest-only) LATEST_ONLY=true ;;
    -E|--include-ea) INCLUDE_EA=true ;;
    -p|--parallel) ((i++)); PARALLEL="${args[$i]:-1}" ;;
    -n|--dry-run) DRY_RUN=true ;;
    -y|--yes) AUTO_YES=true ;;
    -m|--max-per-vendor) ((i++)); MAX_PER_VENDOR="${args[$i]:-0}" ;;
    -l|--list-only) LIST_ONLY=true ;;
    -r|--reinstall) REINSTALL=true ;;
    -k|--keep-going) KEEP_GOING=true ;;
    -K|--no-keep-going) KEEP_GOING=false ;;
    *) echo "Opção desconhecida: ${args[$i]}" >&2; usage; exit 2 ;;
  esac
  ((i++))
done
CANDIDATE="$(echo -n "$CANDIDATE" | tr '[:upper:]' '[:lower:]')"

# -------------------------
# SDKMAN init (robusto)
# -------------------------
export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
if [[ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
  echo "❌ SDKMAN não encontrado em $SDKMAN_DIR. Instale o SDKMAN primeiro."
  exit 1
fi

# Defaults p/ variáveis que os scripts do SDKMAN acessam sem bind:
: "${SDKMAN_OFFLINE_MODE:=false}"
: "${SDKMAN_DEBUG_MODE:=false}"
: "${SDKMAN_CANDIDATES_API:=https://api.sdkman.io/2}"
: "${SDKMAN_FORCE_SELFUPDATE:=false}"
: "${SDKMAN_CANDIDATES_DIR:=$SDKMAN_DIR/candidates}"
: "${ZSH_VERSION:=}"
# Paginadores seguros
: "${PAGER:=cat}"
: "${GIT_PAGER:=cat}"
: "${LESS:=FRSX}"

# Aceitar prompts automaticamente?
if $AUTO_YES; then
  export SDKMAN_AUTO_ACCEPT=true
fi

# Wrapper para QUALQUER chamada ao 'sdk' (subshell com set +u + locale neutro)
sdk_cmd() {
  local subcmd=("$@")
  bash -lc '
    export LC_ALL=C
    export LANG=C
    export SDKMAN_DIR='"$SDKMAN_DIR"'
    export SDKMAN_OFFLINE_MODE='"$SDKMAN_OFFLINE_MODE"'
    export SDKMAN_DEBUG_MODE='"$SDKMAN_DEBUG_MODE"'
    export SDKMAN_CANDIDATES_API='"$SDKMAN_CANDIDATES_API"'
    export SDKMAN_FORCE_SELFUPDATE='"$SDKMAN_FORCE_SELFUPDATE"'
    export SDKMAN_CANDIDATES_DIR='"$SDKMAN_CANDIDATES_DIR"'
    export SDKMAN_AUTO_ACCEPT='"${SDKMAN_AUTO_ACCEPT:-}"'
    export ZSH_VERSION='"$ZSH_VERSION"'
    export PAGER='"${PAGER:-cat}"'
    export GIT_PAGER='"${GIT_PAGER:-cat}"'
    export LESS='"${LESS:-FRSX}"'

    # ⚠️ Mantemos nounset DESLIGADO durante todo o fluxo do SDKMAN
    set +u
    # shellcheck disable=SC1091
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
    sdk "$@"
    # (não religue set -u aqui)
  ' _ "${subcmd[@]}"
}

# -------------------------
# Autodiagnóstico (opcional)
# -------------------------
if $SELFTEST; then
  echo "== SELFTEST SDKMAN =="
  echo "- SDKMAN_DIR: $SDKMAN_DIR"
  echo "- OFFLINE: $SDKMAN_OFFLINE_MODE | DEBUG: $SDKMAN_DEBUG_MODE"
  echo "- API: $SDKMAN_CANDIDATES_API"
  echo "- Locale: LC_ALL=C LANG=C"
  echo "- PAGER: ${PAGER:-<unset>} | GIT_PAGER: ${GIT_PAGER:-<unset>} | LESS: ${LESS:-<unset>}"
  echo "- Teste 'sdk version':"
  sdk_cmd version || { echo "❌ 'sdk version' falhou"; exit 1; }
  echo "- Teste 'sdk list $CANDIDATE' (head):"
  sdk_cmd list "$CANDIDATE" | sed -n '1,80p' || { echo "❌ list falhou"; exit 1; }
  echo "✅ SELFTEST OK."
  exit 0
fi

# -------------------------
# Helpers & parsing
# -------------------------
join_by() { local IFS="$1"; shift; echo "$*"; }
is_in_array() { local n="$1"; shift; local x; for x in "$@"; do [[ "$x" == "$n" ]] && return 0; done; return 1; }
is_lts_version() { [[ "$1" =~ ^(8|11|17|21|25)\. ]]; }
is_ea_identifier() { [[ "$1" == *-ea* || "$1" == *+ea* ]]; }

# Log bruto opcional
debug_dump() {
  $DEBUG_LOG || return 0
  local name="$1"
  local file="/tmp/sdklist-${name}-$$.txt"
  cat > "$file"
  echo "📝 DEBUG salvo: $file"
}

# 1) JAVA — vendors pela coluna 2; fallback por Identifier
list_java_vendors() {
  local raw
  raw="$(sdk_cmd list java || true)"
  # opcionalmente salva raw
  printf "%s" "$raw" | debug_dump "java"

  # Primeiro: parsing por colunas '|'
  vendors_by_col="$(printf "%s" "$raw" | awk -F'\\|' '
    /\|/ && $0 !~ /Vendor/ && $0 !~ /Identifier/ && $0 !~ /^[-+]+$/ {
      v=$2; gsub(/^[ \t]+|[ \t]+$/, "", v);
      if (length(v)>0) print tolower(v);
    }' | sort -u)"

  if [[ -n "$vendors_by_col" ]]; then
    printf "%s\n" "$vendors_by_col"
    return 0
  fi

  # Fallback: inferir vendor pelo sufixo de Identifier (último "-")
  # Pegamos possíveis identifiers (última coluna não-vazia ou tokens vistos)
  vendors_by_id="$(printf "%s" "$raw" | awk -F'\\|' '
    /\|/ && $0 !~ /Identifier/ && $0 !~ /^[-+]+$/ {
      id=$(NF); gsub(/^[ \t]+|[ \t]+$/, "", id);
      if (length(id)>0) print id;
    }' \
    | awk -F'-' 'NF>1{print tolower($NF)}' \
    | sed "s/[[:space:]]\+//g" \
    | grep -E "^[a-z0-9.+]+$" \
    | sort -u)"

  if [[ -n "$vendors_by_id" ]]; then
    printf "%s\n" "$vendors_by_id"
    return 0
  fi

  # Fallback 2: varrer tokens “versão-vendor” mesmo sem pipes
  vendors_by_grep="$(printf "%s" "$raw" \
    | grep -Eo '([0-9][0-9A-Za-z.+-]*-[A-Za-z0-9.+]+)' \
    | awk -F'-' '{print tolower($NF)}' \
    | sort -u)"

  printf "%s\n" "$vendors_by_grep"
}

# 2) JAVA — identifiers por vendor (coluna 6); fallback: pegar qualquer identifier com "-vendor"
list_java_identifiers_for_vendor() {
  local vendor="$1"
  local raw
  raw="$(sdk_cmd list java "$vendor" || true)"
  printf "%s" "$raw" | debug_dump "java-${vendor}"

  ids_by_col="$(printf "%s" "$raw" | awk -F'\\|' '
    /\|/ && $0 !~ /Identifier/ && $0 !~ /Vendor/ && $0 !~ /^[-+]+$/ {
      id=$6; gsub(/^[ \t]+|[ \t]+$/, "", id);
      if (length(id)>0) print id;
    }' | sort -u)"

  if [[ -n "$ids_by_col" ]]; then
    printf "%s\n" "$ids_by_col"
    return 0
  fi

  ids_by_grep="$(printf "%s" "$raw" \
    | grep -Eo '([0-9][0-9A-Za-z.+-]*-[A-Za-z0-9.+]+)' \
    | sort -u)"

  printf "%s\n" "$ids_by_grep"
}

# 3) genérico — identifiers: última coluna; fallback: tokens "versão"
list_generic_versions() {
  local cand="$1"
  local raw
  raw="$(sdk_cmd list "$cand" || true)"
  printf "%s" "$raw" | debug_dump "$cand"

  ids_by_col="$(printf "%s" "$raw" | awk -F'\\|' '
    /\|/ && $0 !~ /Identifier/ && $0 !~ /^[-+]+$/ {
      id=$(NF); gsub(/^[ \t]+|[ \t]+$/, "", id);
      if (length(id)>0) print id;
    }' | sort -u)"

  if [[ -n "$ids_by_col" ]]; then
    printf "%s\n" "$ids_by_col" | grep -E '^[0-9][0-9A-Za-z.+-]*$' || true
    return 0
  fi

  ids_by_grep="$(printf "%s" "$raw" \
    | grep -Eo '(^|[[:space:]\|])([0-9][0-9A-Za-z.+-]+)($|[[:space:]\|])' \
    | sed -E 's/^[[:space:]\|]+|[[:space:]\|]+$//g' \
    | sort -u)"

  printf "%s\n" "$ids_by_grep" | grep -E '^[0-9][0-9A-Za-z.+-]*$' || true
}

# -------------------------
# Construir TO_INSTALL
# -------------------------
TO_INSTALL=()

if [[ "$CANDIDATE" == "java" ]]; then
  mapfile -t ALL_VENDORS < <(list_java_vendors || true)
  if ((${#ALL_VENDORS[@]}==0)); then
    echo "⚠️ Nenhum vendor retornado por 'sdk list java'."
    echo "   Dica: rode com --selftest ou --debug para diagnosticar."
    exit 1
  fi

  # Normalizar filtros p/ lowercase
  if ((${#VENDORS_INCLUDE[@]})); then
    mapfile -t VENDORS_INCLUDE < <(printf "%s\n" "${VENDORS_INCLUDE[@]}" | tr '[:upper:]' '[:lower:]')
  fi
  if ((${#VENDORS_EXCLUDE[@]})); then
    mapfile -t VENDORS_EXCLUDE < <(printf "%s\n" "${VENDORS_EXCLUDE[@]}" | tr '[:upper:]' '[:lower:]')
  fi

  VEND_SEL=()
  if ((${#VENDORS_INCLUDE[@]})); then
    for c in "${ALL_VENDORS[@]}"; do
      is_in_array "$c" "${VENDORS_INCLUDE[@]}" && VEND_SEL+=("$c")
    done
  else
    VEND_SEL=("${ALL_VENDORS[@]}")
  fi
  if ((${#VENDORS_EXCLUDE[@]})); then
    tmp=(); for c in "${VEND_SEL[@]}"; do ! is_in_array "$c" "${VENDORS_EXCLUDE[@]}" && tmp+=("$c"); done
    VEND_SEL=("${tmp[@]}")
  fi
  ((${#VEND_SEL[@]})) || { echo "⚠️ Nenhum vendor após filtros. Saindo."; exit 0; }

  echo "✅ Vendors selecionados (${#VEND_SEL[@]}): $(join_by ', ' "${VEND_SEL[@]}")"

  for vend in "${VEND_SEL[@]}"; do
    mapfile -t IDS < <(list_java_identifiers_for_vendor "$vend" || true)
    filtered=()
    for id in "${IDS[@]}"; do
      $INCLUDE_EA || (! is_ea_identifier "$id") || continue
      if $ONLY_LTS; then
        base="${id%%-*}"; [[ "$base" =~ ^[0-9.]+$ ]] || base="$id"
        ! is_lts_version "$base" && continue
      fi
      [[ -n "$MATCH_REGEX" ]] && ! [[ "$id" =~ $MATCH_REGEX ]] && continue
      filtered+=("$id")
    done
    ((${#filtered[@]})) || { echo "⚠️ Sem versões (após filtros) para vendor $vend."; continue; }
    if $LATEST_ONLY; then
      TO_INSTALL+=("${filtered[-1]}")
    else
      if ((MAX_PER_VENDOR>0)) && ((${#filtered[@]}>MAX_PER_VENDOR)); then
        filtered=("${filtered[@]: -$MAX_PER_VENDOR}")
      fi
      TO_INSTALL+=("${filtered[@]}")
    fi
  done
else
  if ((${#VENDORS_INCLUDE[@]})) || ((${#VENDORS_EXCLUDE[@]})) || $ONLY_LTS || $INCLUDE_EA || ((MAX_PER_VENDOR>0)); then
    echo "ℹ️ Aviso: filtros de vendor/LTS/EA/max-per-vendor são ignorados para candidatos ≠ 'java'."
  fi
  mapfile -t IDS < <(list_generic_versions "$CANDIDATE" || true)
  ((${#IDS[@]})) || { echo "⚠️ Nenhuma versão encontrada para '$CANDIDATE'."; exit 1; }
  filtered=()
  for id in "${IDS[@]}"; do
    [[ -n "$MATCH_REGEX" ]] && ! [[ "$id" =~ $MATCH_REGEX ]] && continue
    filtered+=("$id")
  done
  ((${#filtered[@]})) || { echo "⚠️ Nada a instalar após aplicar filtros."; exit 0; }
  if $LATEST_ONLY; then
    TO_INSTALL+=("${filtered[-1]}")
  else
    TO_INSTALL+=("${filtered[@]}")
  fi
fi

((${#TO_INSTALL[@]})) || { echo "⚠️ Nada a instalar após aplicar filtros."; exit 0; }

echo ""
echo "📋 Versões alvo (${#TO_INSTALL[@]}):"
printf ' - %s\n' "${TO_INSTALL[@]}"

$LIST_ONLY && { echo "ℹ️ --list-only ativo: nenhuma instalação será realizada."; exit 0; }

# -------------------------
# Barra de progresso
# -------------------------
TOTAL=${#TO_INSTALL[@]}
PROG_FILE="$(mktemp)"; echo 0 > "$PROG_FILE"
LOCK_FILE="$PROG_FILE.lock"

progress_tick() {
  local item="$1"
  {
    exec 9>"$LOCK_FILE"
    flock 9
    local n pct
    n=$(<"$PROG_FILE"); n=$((n+1))
    echo "$n" > "$PROG_FILE"
    pct=$(( n * 100 / TOTAL ))
    printf "\r⏳ Progresso: [%d/%d] %d%%  (último: %s)    " "$n" "$TOTAL" "$pct" "$item"
    exec 9>&-
  } 2>/dev/null
}
finish_progress() { echo ""; }

# -------------------------
# Instalação + progresso
# -------------------------
install_one() {
  local ident="$1"

  if $DRY_RUN; then
    echo "[dry-run] sdk install $CANDIDATE $ident"
    progress_tick "$ident"
    return 0
  fi

  if $REINSTALL; then
    echo "🔁 Reinstalando $ident ..."
    # silencioso também no uninstall (não costuma perguntar, mas por segurança)
    sdk_cmd uninstall "$CANDIDATE" "$ident" >/dev/null 2>&1 || true
  fi

  echo "📦 Instalando $ident ... (silencioso)"
  # Respostas automáticas:
  #  1) 'y' -> confirma instalação
  #  2) 'n' -> NÃO definir como default
  local answers=$'y\nn\n'

  if $KEEP_GOING; then
    # Alimenta as respostas via STDIN (sem prompt)
    printf "%b" "$answers" | sdk_cmd install "$CANDIDATE" "$ident" \
      || echo "⚠️ Falha ao instalar $ident (continuando)."
  else
    printf "%b" "$answers" | sdk_cmd install "$CANDIDATE" "$ident"
  fi

  progress_tick "$ident"
}

export -f install_one
export -f sdk_cmd
export -f progress_tick
export TOTAL PROG_FILE LOCK_FILE CANDIDATE DEBUG_LOG
export SDKMAN_DIR SDKMAN_OFFLINE_MODE SDKMAN_DEBUG_MODE SDKMAN_CANDIDATES_API SDKMAN_FORCE_SELFUPDATE SDKMAN_CANDIDATES_DIR SDKMAN_AUTO_ACCEPT ZSH_VERSION PAGER GIT_PAGER LESS

if (( PARALLEL > 1 )); then
  printf '%s\n' "${TO_INSTALL[@]}" | xargs -I{} -P "$PARALLEL" bash -lc 'install_one "$@"' _ {}
else
  for v in "${TO_INSTALL[@]}"; do install_one "$v"; done
fi

finish_progress
rm -f "$PROG_FILE" "$LOCK_FILE" 2>/dev/null || true

echo "🎉 Finalizado."
