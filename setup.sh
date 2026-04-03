#!/usr/bin/env bash

set -euo pipefail

# ── colour helpers ────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_CYAN='\033[0;36m'
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'
  C_DIM='\033[2m'
else
  C_RESET='' C_BOLD='' C_CYAN='' C_GREEN='' C_YELLOW='' C_RED='' C_DIM=''
fi

# ── defaults ──────────────────────────────────────────────────────────────────
REPO_URL="${REPO_URL:-https://github.com/krishkalaria12/dots.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/dots}"
DSEARCH_DIR="${DSEARCH_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/dots/danksearch}"

NON_INTERACTIVE=0
SKIP_PACKAGES=0
SKIP_BACKUP=0
WITH_GIT_CONFIG=0
WITH_ASUS=0

# ── logging ───────────────────────────────────────────────────────────────────
timestamp() { date +"%Y%m%d-%H%M%S"; }

log()  { printf "${C_GREEN}[setup]${C_RESET} %s\n" "$*"; }
info() { printf "${C_CYAN}  →${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[setup] warning:${C_RESET} %s\n" "$*" >&2; }
die()  { printf "${C_RED}[setup] error:${C_RESET} %s\n" "$*" >&2; exit 1; }

# ── usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
usage: setup.sh [options]

installer for the default krishkalaria12/dots arch profile.

prerequisites:
  - Arch Linux with pacman
  - internet access
  - a sudo-enabled user

options:
  --repo-url URL         clone/fetch from a different repo url
  --branch NAME          branch to clone or update (default: ${REPO_BRANCH})
  --repo-dir PATH        target directory for the downloaded repo (default: ${INSTALL_DIR})
  --with-git-config      install the optional ~/.gitconfig shipped in this repo
  --with-asus            install the optional asus hardware package set
  --non-interactive      skip the confirmation prompt
  --skip-packages        skip package installation
  --skip-backup          skip backup creation before overwrite
  -h, --help             show this help message

environment overrides:
  REPO_URL, REPO_BRANCH, INSTALL_DIR, DSEARCH_DIR
EOF
}

# ── argument parsing ──────────────────────────────────────────────────────────
while (($# > 0)); do
  case "$1" in
    --repo-url)
      [[ $# -ge 2 ]] || die "--repo-url requires a value"
      REPO_URL="$2"; shift 2 ;;
    --branch)
      [[ $# -ge 2 ]] || die "--branch requires a value"
      REPO_BRANCH="$2"; shift 2 ;;
    --repo-dir)
      [[ $# -ge 2 ]] || die "--repo-dir requires a value"
      INSTALL_DIR="$2"; shift 2 ;;
    --with-git-config)
      WITH_GIT_CONFIG=1; shift ;;
    --with-asus)
      WITH_ASUS=1; shift ;;
    --non-interactive)
      NON_INTERACTIVE=1; shift ;;
    --skip-packages)
      SKIP_PACKAGES=1; shift ;;
    --skip-backup)
      SKIP_BACKUP=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      die "unknown option: $1" ;;
  esac
done

# ── helpers ───────────────────────────────────────────────────────────────────
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

script_dir() {
  local src="${BASH_SOURCE[0]}"
  dirname "$(readlink -f "$src")"
}

is_repo_root() {
  local path="$1"
  [[ -d "$path/config" && -d "$path/home" && -d "$path/assets" ]]
}

append_unique() {
  local value="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$value" ]] && return 0
  done
  return 1
}

read_manifest_into() {
  local manifest="$1"
  local kind="$2"
  local line

  [[ -f "$manifest" ]] || die "package manifest not found: $manifest"

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*($|#) ]] && continue

    case "$kind" in
      pacman)
        append_unique "$line" "${PACMAN_PACKAGES[@]:-}" || PACMAN_PACKAGES+=("$line")
        ;;
      aur)
        append_unique "$line" "${AUR_PACKAGES[@]:-}" || AUR_PACKAGES+=("$line")
        ;;
      *)
        die "unknown manifest kind: $kind"
        ;;
    esac
  done < "$manifest"
}

core_commands() {
  printf '%s\n' \
    git \
    niri \
    dms \
    go \
    ghostty \
    dolphin \
    nvim \
    zen-browser \
    hyprpicker \
    wl-paste \
    cliphist \
    wpctl \
    nmcli \
    bluetoothctl \
    upower \
    fc-cache \
    brightnessctl \
    grim \
    slurp \
    systemctl
}

core_runtime_paths() {
  printf '%s\n' /usr/lib/polkit-kde-authentication-agent-1
}

optional_commands() {
  if ((WITH_GIT_CONFIG)); then
    printf '%s\n' git
  fi

  if ((WITH_ASUS)); then
    printf '%s\n' asusctl
  fi
}

validate_runtime_requirements() {
  local required=()
  local missing=()
  local required_paths=()
  local missing_paths=()
  local cmd

  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    append_unique "$cmd" "${required[@]:-}" || required+=("$cmd")
  done < <(core_commands)

  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    append_unique "$cmd" "${required[@]:-}" || required+=("$cmd")
  done < <(optional_commands)

  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    append_unique "$cmd" "${required_paths[@]:-}" || required_paths+=("$cmd")
  done < <(core_runtime_paths)

  for cmd in "${required[@]:-}"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  for cmd in "${required_paths[@]:-}"; do
    [[ -x "$cmd" ]] || missing_paths+=("$cmd")
  done

  if ((${#missing[@]})); then
    die "missing required commands for the selected profile: ${missing[*]}"
  fi

  if ((${#missing_paths[@]})); then
    die "missing required runtime files for the selected profile: ${missing_paths[*]}"
  fi
}

require_arch_environment() {
  command -v pacman >/dev/null 2>&1 || die "this installer only supports Arch/pacman-based systems"
  [[ -f /etc/arch-release ]] || warn "'/etc/arch-release' not found; continuing because pacman is available"
}

install_pacman_packages() {
  local packages=("$@")
  ((${#packages[@]})) || return 0

  need_cmd sudo
  log "installing bootstrap pacman packages"
  sudo pacman -S --needed "${packages[@]}"
}

bootstrap_repo_access() {
  local source_root
  source_root="$(script_dir)"

  if is_repo_root "$source_root"; then
    return
  fi

  if command -v git >/dev/null 2>&1; then
    return
  fi

  log "bootstrapping git for repo download"
  install_pacman_packages git
}

bootstrap_yay() {
  local temp_dir yay_dir

  command -v yay >/dev/null 2>&1 && return

  log "bootstrapping yay"
  temp_dir="$(mktemp -d)"
  yay_dir="$temp_dir/yay"

  git clone https://aur.archlinux.org/yay.git "$yay_dir"
  (
    cd "$yay_dir"
    makepkg -si --noconfirm
  )

  rm -rf "$temp_dir"
}

bootstrap_package_tools() {
  if ((SKIP_PACKAGES)); then
    return
  fi

  install_pacman_packages git base-devel
  bootstrap_yay
}

# ── repo resolution ───────────────────────────────────────────────────────────
resolve_repo_dir() {
  local source_root
  source_root="$(script_dir)"
  if is_repo_root "$source_root"; then
    printf '%s\n' "$source_root"
    return
  fi

  need_cmd git

  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "updating repo in $INSTALL_DIR"
    git -C "$INSTALL_DIR" fetch --depth 1 origin "$REPO_BRANCH"
    git -C "$INSTALL_DIR" checkout "$REPO_BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"
  elif [[ -d "$INSTALL_DIR" ]]; then
    die "$INSTALL_DIR exists but is not a git checkout"
  else
    log "cloning repo into $INSTALL_DIR"
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
  fi

  printf '%s\n' "$INSTALL_DIR"
}

# ── plan and package collection ──────────────────────────────────────────────
collect_packages() {
  local repo_root="$1"

  PACMAN_PACKAGES=()
  AUR_PACKAGES=()

  read_manifest_into "$repo_root/packages/pacman.txt" pacman
  read_manifest_into "$repo_root/packages/aur.txt" aur

  if ((WITH_ASUS)); then
    read_manifest_into "$repo_root/packages/optional.txt" pacman
  fi
}

confirm_plan() {
  printf '\n'
  printf "${C_BOLD}${C_CYAN}  Installation plan${C_RESET}\n\n"
  printf "  Profile:\n"
  printf "    ${C_GREEN}✓${C_RESET}  core arch desktop profile\n"
  printf '\n'
  printf "  Extras:\n"
  printf "    [%s] git config\n" "$( ((WITH_GIT_CONFIG)) && printf 'x' || printf ' ' )"
  printf "    [%s] asus hardware\n" "$( ((WITH_ASUS)) && printf 'x' || printf ' ' )"
  printf '\n'
  printf "  Pacman packages: %s\n" "${PACMAN_PACKAGES[*]:-(none)}"
  printf "  AUR packages:    %s\n" "${AUR_PACKAGES[*]:-(none)}"
  if ((SKIP_BACKUP)); then
    printf "  Backup first:    no\n"
  else
    printf "  Backup first:    yes\n"
  fi
  printf '\n'

  if ((NON_INTERACTIVE)); then
    return
  fi

  printf "  Proceed? [Y/n] "
  local ans
  read -r ans
  case "${ans:-y}" in
    y|Y|yes|YES) ;;
    *)
      printf '\n%b  aborted.%b\n\n' "$C_YELLOW" "$C_RESET"
      exit 0 ;;
  esac
}

# ── backups and file install helpers ─────────────────────────────────────────
BACKUP_ROOT=""

ensure_backup_root() {
  if [[ -n "$BACKUP_ROOT" ]]; then
    return
  fi
  BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dots-backups/$(timestamp)"
  mkdir -p "$BACKUP_ROOT"
}

backup_if_exists() {
  local target="$1"
  local rel

  [[ -e "$target" ]] || return 0
  ((SKIP_BACKUP)) && return 0

  ensure_backup_root
  rel="${target#$HOME/}"
  mkdir -p "$BACKUP_ROOT/$(dirname "$rel")"
  cp -a "$target" "$BACKUP_ROOT/$rel"
}

install_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  backup_if_exists "$dest"
  cp -a "$src" "$dest"
}

install_dir() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  backup_if_exists "$dest"
  rm -rf "$dest"
  cp -a "$src" "$dest"
}

install_dir_contents() {
  local src_dir="$1"
  local dest_dir="$2"
  local entry name dest_entry

  mkdir -p "$dest_dir"
  shopt -s nullglob dotglob
  for entry in "$src_dir"/*; do
    name="$(basename "$entry")"
    dest_entry="$dest_dir/$name"
    backup_if_exists "$dest_entry"
    rm -rf "$dest_entry"
    cp -a "$entry" "$dest_entry"
  done
  shopt -u nullglob dotglob
}

install_rendered_home_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  backup_if_exists "$dest"
  sed "s#__HOME__#$HOME#g" "$src" > "$dest"
}

# ── package installation ──────────────────────────────────────────────────────
install_packages() {
  if ((SKIP_PACKAGES)); then
    log "skipping package installation (--skip-packages)"
    return
  fi

  command -v pacman >/dev/null 2>&1 || die "pacman is required for package installation"
  command -v yay >/dev/null 2>&1 || die "yay bootstrap failed"
  need_cmd sudo

  if ((${#PACMAN_PACKAGES[@]})); then
    log "installing pacman packages"
    sudo pacman -S --needed "${PACMAN_PACKAGES[@]}"
  fi

  if ((${#AUR_PACKAGES[@]})); then
    log "installing aur packages"
    yay -S --needed "${AUR_PACKAGES[@]}"
  fi
}

# ── dsearch ───────────────────────────────────────────────────────────────────
render_dsearch_config() {
  local config_dir="$HOME/.config/danksearch"

  mkdir -p "$config_dir"

  cat > "$config_dir/config.toml" <<EOF
index_path = "$HOME/.cache/danksearch/index"
listen_addr = "127.0.0.1:43654"
max_file_bytes = 2097152
worker_count = 4
index_all_files = true

text_extensions = [
  ".txt", ".md", ".go", ".py", ".js", ".ts",
  ".jsx", ".tsx", ".json", ".yaml", ".yml",
  ".toml", ".html", ".css", ".rs", ".c",
  ".cpp", ".h", ".java", ".rb", ".php", ".sh",
  ".lua", ".kdl", ".conf", ".ini",
]

[[index_paths]]
path = "$HOME/Documents"
max_depth = 6
exclude_hidden = false
extract_exif = true
exclude_dirs = ["node_modules", "__pycache__", ".cache"]

[[index_paths]]
path = "$HOME/Desktop"
max_depth = 5
exclude_hidden = true
extract_exif = false
exclude_dirs = ["node_modules", "__pycache__", ".cache"]

[[index_paths]]
path = "$HOME/Downloads"
max_depth = 4
exclude_hidden = true
extract_exif = false
exclude_dirs = ["node_modules", "__pycache__", ".cache"]
EOF
}

install_dsearch() {
  need_cmd git
  need_cmd go

  mkdir -p "$(dirname "$DSEARCH_DIR")"
  if [[ -d "$DSEARCH_DIR/.git" ]]; then
    git -C "$DSEARCH_DIR" pull --ff-only
  else
    git clone https://github.com/AvengeMedia/danksearch "$DSEARCH_DIR"
  fi

  (
    cd "$DSEARCH_DIR"
    CGO_ENABLED=0 go build -ldflags='-s -w' -o bin/dsearch cmd/dsearch/*.go
  )

  mkdir -p "$HOME/.local/bin"
  install_file "$DSEARCH_DIR/bin/dsearch" "$HOME/.local/bin/dsearch"
  chmod +x "$HOME/.local/bin/dsearch"
}

apply_core_profile() {
  local repo_root="$1"

  install_file "$repo_root/home/.profile" "$HOME/.profile"
  install_file "$repo_root/home/.zshrc" "$HOME/.zshrc"
  install_dir  "$repo_root/config/fish" "$HOME/.config/fish"

  install_dir "$repo_root/config/ghostty" "$HOME/.config/ghostty"
  install_dir "$repo_root/config/niri" "$HOME/.config/niri"

  install_dir  "$repo_root/config/DankMaterialShell" "$HOME/.config/DankMaterialShell"
  install_file "$repo_root/services/user/dms.service" "$HOME/.config/systemd/user/dms.service"

  install_file "$repo_root/config/dolphinrc" "$HOME/.config/dolphinrc"
  install_file "$repo_root/config/kdeglobals" "$HOME/.config/kdeglobals"
  install_dir  "$repo_root/config/qt5ct" "$HOME/.config/qt5ct"
  install_dir  "$repo_root/config/qt6ct" "$HOME/.config/qt6ct"
  install_rendered_home_file "$repo_root/config/qt5ct/qt5ct.conf" "$HOME/.config/qt5ct/qt5ct.conf"
  install_rendered_home_file "$repo_root/config/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"

  install_dir  "$repo_root/config/btop" "$HOME/.config/btop"
  install_file "$repo_root/local/bin/brightness" "$HOME/.local/bin/brightness"
  install_file "$repo_root/local/bin/niri-screenshot-select.sh" "$HOME/.local/bin/niri-screenshot-select.sh"
  chmod +x "$HOME/.local/bin/brightness" "$HOME/.local/bin/niri-screenshot-select.sh"

  install_dir_contents "$repo_root/assets/fonts" "$HOME/.local/share/fonts"
  install_dir_contents "$repo_root/assets/icons" "$HOME/.local/share/icons"
  install_dir_contents "$repo_root/assets/wallpapers" "$HOME/Pictures/Wallpapers"
}

apply_optional_features() {
  local repo_root="$1"

  if ((WITH_GIT_CONFIG)); then
    info "git config"
    install_file "$repo_root/home/.gitconfig" "$HOME/.gitconfig"
  fi
}

apply_profile() {
  local repo_root="$1"

  mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.config/systemd/user" "$HOME/.local/share/fonts" "$HOME/.local/share/icons" "$HOME/Pictures/Wallpapers"

  log "installing core profile"
  info "core profile"
  apply_core_profile "$repo_root"
  info "search"
  install_file "$repo_root/services/user/dsearch.service" "$HOME/.config/systemd/user/dsearch.service"
  render_dsearch_config
  install_dsearch
  apply_optional_features "$repo_root"
}

post_install() {
  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -fv >/dev/null || true
  fi

  if ! systemctl --user daemon-reload; then
    warn "failed to reload user systemd units"
    return
  fi

  systemctl --user enable --now dms.service || warn "failed to enable dms.service"

  if command -v dsearch >/dev/null 2>&1; then
    systemctl --user enable --now dsearch.service || warn "failed to enable dsearch.service"
  fi
}

# ── banner ────────────────────────────────────────────────────────────────────
print_banner() {
  printf '\n'
  printf "${C_BOLD}${C_CYAN}"
  printf '  ██████╗  ██████╗ ████████╗███████╗\n'
  printf '  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝\n'
  printf '  ██║  ██║██║   ██║   ██║   ███████╗\n'
  printf '  ██║  ██║██║   ██║   ██║   ╚════██║\n'
  printf '  ██████╔╝╚██████╔╝   ██║   ███████║\n'
  printf '  ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝\n'
  printf "${C_RESET}"
  printf "${C_DIM}  krishkalaria12 · niri + dms dotfiles${C_RESET}\n\n"
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  print_banner
  require_arch_environment
  bootstrap_repo_access

  local repo_root
  repo_root="$(resolve_repo_dir)"

  collect_packages "$repo_root"
  confirm_plan

  bootstrap_package_tools
  install_packages
  validate_runtime_requirements
  apply_profile "$repo_root"
  post_install

  printf '\n'
  log 'done'
  if [[ -n "$BACKUP_ROOT" ]]; then
    printf '  backup: %s\n' "$BACKUP_ROOT"
  fi
  printf '  repo:   %s\n' "$repo_root"
  printf '  next:   log out and choose the niri session if needed\n\n'
}

main "$@"
