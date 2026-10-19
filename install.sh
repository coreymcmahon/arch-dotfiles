#!/usr/bin/env bash
# arch-dotfiles installer: runs the provisioning stages under stages/ in order.
#
#   ./install.sh                     run all default stages
#   ./install.sh --stage desktop     run one stage (repeatable)
#   ./install.sh --from development  resume from a stage
#   ./install.sh --dry-run           show what would happen
#   ./install.sh --stage dotfiles hypr waybar   extra args go to the stage
#
# Works from any working directory. Never run as root.

# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
install_traps

DEFAULT_STAGES=(system aur desktop development dotfiles services)
EXTRA_STAGES=(optional)

usage() {
  cat <<USAGE
Usage: ${0##*/} [options] [-- stage arguments]

Options:
  --stage NAME         Run only this stage (may be repeated; order is preserved)
  --from NAME          Run NAME and every default stage after it (resume)
  --list               List stages and exit
  --dry-run            Print planned actions without changing the system
  --backup-conflicts   dotfiles: move conflicting files to ~/.dotfiles-backup/ instead of failing
  --interactive        Let pacman/yay prompt instead of passing --noconfirm
  -h, --help           Show this help

Default stages, in order: ${DEFAULT_STAGES[*]}
Extra stages (run only when named): ${EXTRA_STAGES[*]}

Positional arguments are passed to each selected stage, e.g.
  ${0##*/} --stage dotfiles hypr waybar
USAGE
}

stage_script() {
  local name=$1 match
  for match in "$STAGES_DIR"/[0-9][0-9]-"$name".sh; do
    [[ -f "$match" ]] && { printf '%s\n' "$match"; return 0; }
  done
  return 1
}

list_stages() {
  local s
  for s in "${DEFAULT_STAGES[@]}"; do printf '%-12s %s\n' "$s" "$(stage_script "$s")"; done
  for s in "${EXTRA_STAGES[@]}"; do printf '%-12s %s (not run by default)\n' "$s" "$(stage_script "$s")"; done
}

is_known_stage() {
  local s
  for s in "${DEFAULT_STAGES[@]}" "${EXTRA_STAGES[@]}"; do [[ "$s" == "$1" ]] && return 0; done
  return 1
}

selected=()
from=''
stage_args=()
while (( $# )); do
  case "$1" in
    --stage)   [[ -n "${2:-}" ]] || die "--stage requires a name"; selected+=("$2"); shift 2 ;;
    --stage=*) selected+=("${1#--stage=}"); shift ;;
    --from)    [[ -n "${2:-}" ]] || die "--from requires a name"; from=$2; shift 2 ;;
    --from=*)  from="${1#--from=}"; shift ;;
    --list)    list_stages; exit 0 ;;
    --dry-run|-n) DRY_RUN=1; shift ;;
    --backup-conflicts) BACKUP_CONFLICTS=1; shift ;;
    --interactive) NOCONFIRM=0; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; stage_args+=("$@"); break ;;
    -*) error "Unknown option: $1"; usage >&2; exit 2 ;;
    *)  stage_args+=("$1"); shift ;;
  esac
done
export DRY_RUN NOCONFIRM BACKUP_CONFLICTS="${BACKUP_CONFLICTS:-0}"

if [[ -n "$from" ]]; then
  (( ${#selected[@]} == 0 )) || die "--from cannot be combined with --stage"
  found=0
  for s in "${DEFAULT_STAGES[@]}"; do
    [[ "$s" == "$from" ]] && found=1
    (( found )) && selected+=("$s")
  done
  (( found )) || { error "Unknown stage: $from"; list_stages >&2; exit 2; }
fi
(( ${#selected[@]} )) || selected=("${DEFAULT_STAGES[@]}")

for s in "${selected[@]}"; do
  is_known_stage "$s" || { error "Unknown stage: $s"; list_stages >&2; exit 2; }
done

# --- Preflight ----------------------------------------------------------------
require_not_root
if ! is_arch; then
  if [[ "$DRY_RUN" == 1 ]]; then
    warn "Not running on Arch Linux; dry-run will treat every package as missing."
  else
    die "This installer targets Arch Linux (/etc/arch-release not found). Use --dry-run elsewhere."
  fi
fi
[[ "$DRY_RUN" == 1 ]] && log "Dry run: nothing will be changed."
sudo_keepalive

# --- Run ----------------------------------------------------------------------
total=${#selected[@]}
i=0
start_all=$SECONDS
for s in "${selected[@]}"; do
  i=$((i + 1))
  script=$(stage_script "$s")
  printf '\n%s[%d/%d]%s Stage: %s\n' "$C_BLUE" "$i" "$total" "$C_RESET" "$s"
  start=$SECONDS
  rc=0
  PACMAN_SYNCED="$PACMAN_SYNCED" bash "$script" "${stage_args[@]}" || rc=$?
  if (( rc != 0 )); then
    printf '\n'
    error "Stage '$s' failed (exit $rc) after $((SECONDS - start))s."
    info "Fix the problem above, then resume with:"
    info "  $DOTFILES_DIR/install.sh --from $s"
    info "or rerun just this stage:"
    info "  $DOTFILES_DIR/install.sh --stage $s"
    exit "$rc"
  fi
  # Once the system stage has synced the databases, later stages can use -S.
  [[ "$s" == system ]] && PACMAN_SYNCED=1
  info "($((SECONDS - start))s)"
done

printf '\n'
ok "All selected stages finished in $((SECONDS - start_all))s: ${selected[*]}"
if [[ "$DRY_RUN" != 1 ]]; then
  info "Next: log out and back in (docker group, mise in ~/.bashrc), then start Hyprland from a TTY with: Hyprland"
fi
