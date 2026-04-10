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
STATE_ROOT="${STATE_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/dots}"
INSTALL_MANIFEST="${INSTALL_MANIFEST:-$STATE_ROOT/install-manifest.txt}"
LAST_INSTALL_FILE="${LAST_INSTALL_FILE:-$STATE_ROOT/last-install.txt}"
FIRSTRUN_FILE="${FIRSTRUN_FILE:-$STATE_ROOT/installed_true}"

NON_INTERACTIVE=0
SKIP_PACKAGES=0
SKIP_BACKUP=0
WITH_GIT_CONFIG=0
WITH_ASUS=0
COMPOSITOR="${COMPOSITOR:-niri}"
CURRENT_MANIFEST_FILE=""
INSTALL_FIRSTRUN=0

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
  --compositor NAME      install compositor profile: niri or hyprland (default: ${COMPOSITOR})
  --non-interactive      skip the confirmation prompt
  --skip-packages        skip package installation
  --skip-backup          skip backup creation before overwrite
  -h, --help             show this help message

environment overrides:
  REPO_URL, REPO_BRANCH, INSTALL_DIR, DSEARCH_DIR, COMPOSITOR
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
    --compositor)
      [[ $# -ge 2 ]] || die "--compositor requires a value"
      COMPOSITOR="$2"; shift 2 ;;
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

validate_compositor() {
  case "$COMPOSITOR" in
    niri|hyprland) ;;
    *)
      die "unsupported compositor: $COMPOSITOR (expected: niri or hyprland)"
      ;;
  esac
}

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
    dms \
    go \
    ghostty \
    dolphin \
    nvim \
    sddm \
    rsync \
    xdg-user-dirs-update \
    zen-browser \
    hyprpicker \
    wl-copy \
    wl-paste \
    cliphist \
    wpctl \
    nmcli \
    bluetoothctl \
    upower \
    fc-cache \
    dbus-update-activation-environment \
    gnome-keyring-daemon \
    brightnessctl \
    grim \
    slurp \
    systemctl
}

core_runtime_paths() {
  printf '%s\n' /usr/lib/polkit-kde-authentication-agent-1
}

compositor_commands() {
  case "$COMPOSITOR" in
    niri)
      printf '%s\n' niri
      ;;
    hyprland)
      printf '%s\n' \
        Hyprland \
        hypridle \
        hyprlock \
        hyprpaper \
        hyprshot
      ;;
  esac
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
    append_unique "$cmd" "${required[@]:-}" || required+=("$cmd")
  done < <(compositor_commands)

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

ensure_state_root() {
  mkdir -p "$STATE_ROOT"
}

begin_install_state() {
  ensure_state_root

  if [[ -f "$FIRSTRUN_FILE" ]]; then
    INSTALL_FIRSTRUN=0
  else
    INSTALL_FIRSTRUN=1
  fi

  CURRENT_MANIFEST_FILE="$(mktemp "$STATE_ROOT/install-manifest.XXXXXX")"
}

cleanup_install_state() {
  if [[ -n "$CURRENT_MANIFEST_FILE" && -f "$CURRENT_MANIFEST_FILE" ]]; then
    rm -f "$CURRENT_MANIFEST_FILE"
  fi
}

record_installed_target() {
  local target="$1"
  [[ -n "$CURRENT_MANIFEST_FILE" ]] || return 0
  [[ -e "$target" ]] || return 0

  realpath -se "$target" >> "$CURRENT_MANIFEST_FILE"
}

record_dir_tree() {
  local target_dir="$1"
  [[ -d "$target_dir" ]] || return 0

  record_installed_target "$target_dir"
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    record_installed_target "$path"
  done < <(find "$target_dir" -mindepth 1 -print | sort)
}

finalize_install_state() {
  ensure_state_root
  [[ -n "$CURRENT_MANIFEST_FILE" && -f "$CURRENT_MANIFEST_FILE" ]] || return 0

  sort -u "$CURRENT_MANIFEST_FILE" > "$INSTALL_MANIFEST"
  touch "$FIRSTRUN_FILE"

  cat > "$LAST_INSTALL_FILE" <<EOF
timestamp=$(timestamp)
repo_dir=$1
first_run=$INSTALL_FIRSTRUN
with_git_config=$WITH_GIT_CONFIG
with_asus=$WITH_ASUS
compositor=$COMPOSITOR
EOF

  cleanup_install_state
}

verify_exists() {
  local path="$1"
  [[ -e "$path" ]] || die "missing expected installed path: $path"
}

verify_system_service_enabled() {
  local unit="$1"
  systemctl is-enabled --quiet "$unit" || die "system service is not enabled: $unit"
}

verify_user_service_enabled() {
  local unit="$1"
  run_user_systemctl is-enabled "$unit" >/dev/null 2>&1 || die "user service is not enabled: $unit"
}

ensure_user_in_group() {
  local group_name="$1"
  local user_name

  getent group "$group_name" >/dev/null 2>&1 || return 0

  user_name="$(id -un)"
  if id -nG "$user_name" | tr ' ' '\n' | grep -Fx "$group_name" >/dev/null 2>&1; then
    return 0
  fi

  need_cmd sudo
  info "adding $user_name to $group_name group"
  sudo usermod -aG "$group_name" "$user_name"
}

enable_system_service() {
  local unit="$1"

  need_cmd sudo
  info "enabling $unit"
  sudo systemctl enable --now "$unit"
}

run_user_systemctl() {
  local user_name
  user_name="$(id -un)"

  if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" && -n "${XDG_RUNTIME_DIR:-}" ]]; then
    systemctl --user "$@"
  else
    need_cmd sudo
    sudo systemctl --machine="${user_name}@.host" --user "$@"
  fi
}

setup_system() {
  log "configuring system services"

  if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    info "updating xdg user directories"
    xdg-user-dirs-update
  fi

  ensure_user_in_group video
  enable_system_service NetworkManager.service
  enable_system_service bluetooth.service
  enable_system_service sddm.service
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
  read_manifest_into "$repo_root/packages/compositor-${COMPOSITOR}.txt" pacman

  if ((WITH_ASUS)); then
    read_manifest_into "$repo_root/packages/optional-asus.txt" pacman
  fi
}

confirm_plan() {
  printf '\n'
  printf "${C_BOLD}${C_CYAN}  Installation plan${C_RESET}\n\n"
  printf "  Profile:\n"
  printf "    ${C_GREEN}✓${C_RESET}  core arch desktop profile\n"
  printf "    ${C_GREEN}✓${C_RESET}  compositor: %s\n" "$COMPOSITOR"
  printf '\n'
  printf "  Extras:\n"
  printf "    [%s] git config\n" "$( ((WITH_GIT_CONFIG)) && printf 'x' || printf ' ' )"
  printf "    [%s] asus hardware\n" "$( ((WITH_ASUS)) && printf 'x' || printf ' ' )"
  printf '\n'
  printf "  Pacman packages: %s\n" "${PACMAN_PACKAGES[*]:-(none)}"
  printf "  AUR packages:    %s\n" "${AUR_PACKAGES[*]:-(none)}"
  printf "  System services: %s\n" "NetworkManager.service bluetooth.service sddm.service"
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
  record_installed_target "$dest"
}

install_dir() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  backup_if_exists "$dest"
  mkdir -p "$dest"
  rsync -a --delete "$src"/ "$dest"/
  record_dir_tree "$dest"
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
    if [[ -d "$dest_entry" ]]; then
      record_dir_tree "$dest_entry"
    else
      record_installed_target "$dest_entry"
    fi
  done
  shopt -u nullglob dotglob
}

install_rendered_home_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  backup_if_exists "$dest"
  sed "s#__HOME__#$HOME#g" "$src" > "$dest"
  record_installed_target "$dest"
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
  install_dir "$repo_root/config/xdg-desktop-portal" "$HOME/.config/xdg-desktop-portal"

  install_dir  "$repo_root/config/DankMaterialShell" "$HOME/.config/DankMaterialShell"
  install_file "$repo_root/services/user/dms.service" "$HOME/.config/systemd/user/dms.service"

  install_file "$repo_root/config/chrome-flags.conf" "$HOME/.config/chrome-flags.conf"
  install_file "$repo_root/config/dolphinrc" "$HOME/.config/dolphinrc"
  install_file "$repo_root/config/kdeglobals" "$HOME/.config/kdeglobals"
  install_dir  "$repo_root/config/qt5ct" "$HOME/.config/qt5ct"
  install_dir  "$repo_root/config/qt6ct" "$HOME/.config/qt6ct"
  install_rendered_home_file "$repo_root/config/qt5ct/qt5ct.conf" "$HOME/.config/qt5ct/qt5ct.conf"
  install_rendered_home_file "$repo_root/config/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"

  install_dir  "$repo_root/config/btop" "$HOME/.config/btop"
  install_file "$repo_root/local/bin/brightness" "$HOME/.local/bin/brightness"
  chmod +x "$HOME/.local/bin/brightness"

  install_dir_contents "$repo_root/assets/fonts" "$HOME/.local/share/fonts"
  install_dir_contents "$repo_root/assets/icons" "$HOME/.local/share/icons"
  install_dir_contents "$repo_root/assets/wallpapers" "$HOME/Pictures/Wallpapers"
}

apply_compositor_profile() {
  local repo_root="$1"

  case "$COMPOSITOR" in
    niri)
      info "compositor: niri"
      install_dir "$repo_root/config/niri" "$HOME/.config/niri"
      install_file "$repo_root/local/bin/niri-screenshot-select.sh" "$HOME/.local/bin/niri-screenshot-select.sh"
      chmod +x "$HOME/.local/bin/niri-screenshot-select.sh"
      ;;
    hyprland)
      info "compositor: hyprland"
      install_dir "$repo_root/config/hypr" "$HOME/.config/hypr"
      install_rendered_home_file "$repo_root/config/hypr/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
      install_rendered_home_file "$repo_root/config/hypr/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf"
      ;;
  esac
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
  apply_compositor_profile "$repo_root"
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

  if ! run_user_systemctl daemon-reload; then
    warn "failed to reload user systemd units"
    return
  fi

  run_user_systemctl enable --now dms.service || warn "failed to enable dms.service"

  if command -v dsearch >/dev/null 2>&1; then
    run_user_systemctl enable --now dsearch.service || warn "failed to enable dsearch.service"
  fi
}

verify_install() {
  log "verifying installed profile"

  verify_system_service_enabled NetworkManager.service
  verify_system_service_enabled bluetooth.service
  verify_system_service_enabled sddm.service

  verify_user_service_enabled dms.service
  verify_user_service_enabled dsearch.service

  verify_exists "$HOME/.config/systemd/user/dms.service"
  verify_exists "$HOME/.config/systemd/user/dsearch.service"
  verify_exists "$HOME/.local/bin/dsearch"
  verify_exists "$HOME/.local/bin/brightness"
  case "$COMPOSITOR" in
    niri)
      verify_exists "$HOME/.config/niri/config.kdl"
      verify_exists "$HOME/.local/bin/niri-screenshot-select.sh"
      ;;
    hyprland)
      verify_exists "$HOME/.config/hypr/hyprland.conf"
      verify_exists "$HOME/.config/hypr/hypridle.conf"
      verify_exists "$HOME/.config/hypr/hyprlock.conf"
      verify_exists "$HOME/.config/hypr/hyprpaper.conf"
      verify_exists "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf"
      ;;
  esac
  verify_exists "$INSTALL_MANIFEST"
  verify_exists "$LAST_INSTALL_FILE"
  verify_exists "$FIRSTRUN_FILE"
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
  printf "${C_DIM}  krishkalaria12 · compositor-selectable dms dotfiles${C_RESET}\n\n"
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  print_banner
  validate_compositor
  require_arch_environment
  bootstrap_repo_access

  local repo_root
  repo_root="$(resolve_repo_dir)"

  collect_packages "$repo_root"
  confirm_plan

  bootstrap_package_tools
  install_packages
  validate_runtime_requirements
  begin_install_state
  trap cleanup_install_state EXIT INT TERM
  setup_system
  apply_profile "$repo_root"
  post_install
  finalize_install_state "$repo_root"
  verify_install
  trap - EXIT INT TERM

  printf '\n'
  log 'done'
  if [[ -n "$BACKUP_ROOT" ]]; then
    printf '  backup: %s\n' "$BACKUP_ROOT"
  fi
  printf '  state:  %s\n' "$STATE_ROOT"
  printf '  repo:   %s\n' "$repo_root"
  printf '  next:   reboot or log out, then choose the %s session in sddm\n\n' "$COMPOSITOR"
}

main "$@"
