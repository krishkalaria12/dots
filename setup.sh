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
COMPONENTS_ARG=""

# ── component catalogue ───────────────────────────────────────────────────────
# package tokens prefixed with aur: are installed with yay.
COMPONENT_DEFS=(
  "shell|Home shell env, fish, zsh, git config|fish zsh fastfetch starship zoxide"
  "terminal|Ghostty terminal|ghostty"
  "niri|Niri compositor config|niri"
  "dms|Dank Material Shell, launcher, and shell integration|aur:dms-shell-git hyprpicker wl-clipboard cliphist pipewire wireplumber"
  "desktop|Dolphin plus KDE/Qt theming|dolphin qt5ct-kde qt6ct-kde"
  "tools|Btop and local helper scripts|btop grim slurp brightnessctl"
  "apps|Default app targets from keybinds|aur:zed-preview-bin aur:zen-browser-bin"
  "assets|Fonts, cursor theme, and wallpapers|aur:whitesur-icon-theme papirus-icon-theme"
  "search|DankSearch file search backend|go"
)

DEFAULT_COMPONENTS=(shell terminal niri dms desktop tools apps assets)

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

interactive installer for krishkalaria12/dots (arch linux + niri + dms).

prerequisites:
  - git
  - yay

options:
  --repo-url URL         clone/fetch from a different repo url
  --branch NAME          branch to clone or update (default: ${REPO_BRANCH})
  --repo-dir PATH        target directory for the downloaded repo (default: ${INSTALL_DIR})
  --components LIST      comma-separated list of components to install without
                         the interactive menu (e.g. shell,terminal,niri)
                         valid components: shell terminal niri dms desktop tools apps assets search
  --non-interactive      install all components without prompting
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
    --components)
      [[ $# -ge 2 ]] || die "--components requires a value"
      COMPONENTS_ARG="$2"; NON_INTERACTIVE=1; shift 2 ;;
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

field() { printf '%s\n' "$1" | cut -d'|' -f"$2"; }
comp_key()  { field "$1" 1; }
comp_desc() { field "$1" 2; }
comp_pkgs() { printf '%s\n' "$1" | cut -d'|' -f3-; }

append_unique() {
  local value="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$value" ]] && return 0
  done
  return 1
}

# ── repo resolution ───────────────────────────────────────────────────────────
resolve_repo_dir() {
  local source_root
  source_root="$(script_dir)"
  if [[ -d "$source_root/config" && -d "$source_root/home" && -d "$source_root/assets" ]]; then
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

# ── interactive component selection ──────────────────────────────────────────
interactive_component_menu() {
  local n=${#COMPONENT_DEFS[@]}
  local selected=()
  local i key def default_comp

  for ((i = 0; i < n; i++)); do
    def="${COMPONENT_DEFS[$i]}"
    key="$(comp_key "$def")"
    selected[i]=0
    for default_comp in "${DEFAULT_COMPONENTS[@]}"; do
      if [[ "$default_comp" == "$key" ]]; then
        selected[i]=1
        break
      fi
    done
  done

  while true; do
    printf '\n'
    printf "${C_BOLD}${C_CYAN}  Select components to install${C_RESET}\n"
    printf "${C_DIM}  Toggle with a number · (a) all · (n) none · (d) done · (q) quit${C_RESET}\n\n"

    for ((i = 0; i < n; i++)); do
      local def key desc checkbox
      def="${COMPONENT_DEFS[$i]}"
      key="$(comp_key "$def")"
      desc="$(comp_desc "$def")"
      if ((selected[i])); then
        checkbox="${C_GREEN}[✓]${C_RESET}"
      else
        checkbox="${C_DIM}[ ]${C_RESET}"
      fi
      printf "  %b  %2d)  %-12s  %b%s%b\n" "$checkbox" $((i + 1)) "$key" "$C_BOLD" "$desc" "$C_RESET"
    done

    printf '\n'
    printf "${C_CYAN}  choice:${C_RESET} "
    local choice
    read -r choice

    case "$choice" in
      a|A)
        for ((i = 0; i < n; i++)); do selected[i]=1; done ;;
      n|N)
        for ((i = 0; i < n; i++)); do selected[i]=0; done ;;
      d|D|'')
        break ;;
      q|Q)
        printf '\n%b  aborted.%b\n\n' "$C_YELLOW" "$C_RESET"
        exit 0 ;;
      *)
        local token
        for token in ${choice//,/ }; do
          if [[ "$token" =~ ^[0-9]+$ ]] && ((token >= 1 && token <= n)); then
            local idx=$((token - 1))
            selected[idx]=$((1 - selected[idx]))
          else
            printf "  ${C_YELLOW}ignoring unknown input: %s${C_RESET}\n" "$token"
          fi
        done
        ;;
    esac
  done

  SELECTED_COMPONENTS=()
  for ((i = 0; i < n; i++)); do
    if ((selected[i])); then
      SELECTED_COMPONENTS+=("$(comp_key "${COMPONENT_DEFS[$i]}")")
    fi
  done
}

resolve_selected_components() {
  SELECTED_COMPONENTS=()

  if ((NON_INTERACTIVE)); then
    if [[ -z "$COMPONENTS_ARG" || "$COMPONENTS_ARG" == "all" ]]; then
      local def
      for def in "${COMPONENT_DEFS[@]}"; do
        SELECTED_COMPONENTS+=("$(comp_key "$def")")
      done
    else
      IFS=',' read -ra SELECTED_COMPONENTS <<< "$COMPONENTS_ARG"
      local comp def found
      for comp in "${SELECTED_COMPONENTS[@]}"; do
        found=0
        for def in "${COMPONENT_DEFS[@]}"; do
          [[ "$(comp_key "$def")" == "$comp" ]] && found=1 && break
        done
        ((found)) || die "unknown component '$comp'"
      done
    fi
    return
  fi

  interactive_component_menu
}

# ── plan and package collection ──────────────────────────────────────────────
collect_packages() {
  PACMAN_PACKAGES=()
  AUR_PACKAGES=()

  local comp def token token_list
  for comp in "${SELECTED_COMPONENTS[@]}"; do
    for def in "${COMPONENT_DEFS[@]}"; do
      [[ "$(comp_key "$def")" == "$comp" ]] || continue
      token_list="$(comp_pkgs "$def")"
      for token in $token_list; do
        if [[ "$token" == aur:* ]]; then
          token="${token#aur:}"
          append_unique "$token" "${AUR_PACKAGES[@]:-}" || AUR_PACKAGES+=("$token")
        else
          append_unique "$token" "${PACMAN_PACKAGES[@]:-}" || PACMAN_PACKAGES+=("$token")
        fi
      done
      break
    done
  done
}

confirm_plan() {
  printf '\n'
  printf "${C_BOLD}${C_CYAN}  Installation plan${C_RESET}\n\n"
  printf "  Components:\n"
  local comp
  for comp in "${SELECTED_COMPONENTS[@]}"; do
    printf "    ${C_GREEN}✓${C_RESET}  %s\n" "$comp"
  done
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

# ── package installation ──────────────────────────────────────────────────────
install_packages() {
  if ((SKIP_PACKAGES)); then
    log "skipping package installation (--skip-packages)"
    return
  fi

  command -v pacman >/dev/null 2>&1 || die "pacman is required for package installation"
  command -v yay >/dev/null 2>&1 || die "yay is required for AUR packages. install yay first."
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
  local coding_root="$HOME/Desktop/Coding"
  local coding_block=""

  mkdir -p "$config_dir"
  if [[ -d "$coding_root" ]]; then
    coding_block=$(cat <<EOF
[[index_paths]]
path = "$coding_root"
max_depth = 8
exclude_hidden = true
extract_exif = false
exclude_dirs = [
  "node_modules", "bower_components", "__pycache__", "site-packages",
  "venv", ".venv", "target", "dist", "build", "vendor", ".cache",
  ".git", ".idea", ".vscode", "coverage", ".next", "out"
]

EOF
)
  fi

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

${coding_block}[[index_paths]]
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

# ── component application ────────────────────────────────────────────────────
apply_component() {
  local repo_root="$1"
  local comp="$2"

  case "$comp" in
    shell)
      install_file "$repo_root/home/.profile" "$HOME/.profile"
      install_file "$repo_root/home/.zshrc" "$HOME/.zshrc"
      install_file "$repo_root/home/.gitconfig" "$HOME/.gitconfig"
      install_dir  "$repo_root/config/fish" "$HOME/.config/fish"
      ;;
    terminal)
      install_dir "$repo_root/config/ghostty" "$HOME/.config/ghostty"
      ;;
    niri)
      install_dir "$repo_root/config/niri" "$HOME/.config/niri"
      ;;
    dms)
      install_dir  "$repo_root/config/DankMaterialShell" "$HOME/.config/DankMaterialShell"
      install_file "$repo_root/services/user/dms.service" "$HOME/.config/systemd/user/dms.service"
      ;;
    desktop)
      install_file "$repo_root/config/dolphinrc" "$HOME/.config/dolphinrc"
      install_file "$repo_root/config/kdeglobals" "$HOME/.config/kdeglobals"
      install_dir  "$repo_root/config/qt5ct" "$HOME/.config/qt5ct"
      install_dir  "$repo_root/config/qt6ct" "$HOME/.config/qt6ct"
      ;;
    tools)
      install_dir  "$repo_root/config/btop" "$HOME/.config/btop"
      install_file "$repo_root/local/bin/brightness" "$HOME/.local/bin/brightness"
      install_file "$repo_root/local/bin/niri-screenshot-select.sh" "$HOME/.local/bin/niri-screenshot-select.sh"
      chmod +x "$HOME/.local/bin/brightness" "$HOME/.local/bin/niri-screenshot-select.sh"
      ;;
    apps)
      ;;
    assets)
      install_dir_contents "$repo_root/assets/fonts" "$HOME/.local/share/fonts"
      install_dir_contents "$repo_root/assets/icons" "$HOME/.local/share/icons"
      install_dir_contents "$repo_root/assets/wallpapers" "$HOME/Pictures/Wallpapers"
      ;;
    search)
      install_file "$repo_root/services/user/dsearch.service" "$HOME/.config/systemd/user/dsearch.service"
      render_dsearch_config
      install_dsearch
      ;;
    *)
      die "unknown component: $comp"
      ;;
  esac
}

apply_selected_components() {
  local repo_root="$1"
  local comp

  mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.config/systemd/user" "$HOME/.local/share/fonts" "$HOME/.local/share/icons" "$HOME/Pictures/Wallpapers"

  log "installing selected components"
  for comp in "${SELECTED_COMPONENTS[@]}"; do
    info "$comp"
    apply_component "$repo_root" "$comp"
  done
}

post_install() {
  local comp has_assets=0 has_dms=0 has_search=0

  for comp in "${SELECTED_COMPONENTS[@]}"; do
    [[ "$comp" == "assets" ]] && has_assets=1
    [[ "$comp" == "dms" ]] && has_dms=1
    [[ "$comp" == "search" ]] && has_search=1
  done

  if ((has_assets)); then
    fc-cache -fv >/dev/null || true
  fi

  if command -v gsettings >/dev/null 2>&1; then
    if ((has_assets)); then
      gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark' || true
      gsettings set org.gnome.desktop.interface cursor-theme 'Sweet-cursors' || true
    fi
  fi

  systemctl --user daemon-reload || true
  if ((has_dms)); then
    systemctl --user enable --now dms.service || true
  fi
  if ((has_search)) && command -v dsearch >/dev/null 2>&1; then
    systemctl --user enable --now dsearch.service || true
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

  local repo_root
  repo_root="$(resolve_repo_dir)"

  resolve_selected_components
  [[ ${#SELECTED_COMPONENTS[@]} -gt 0 ]] || die "no components selected"

  collect_packages
  confirm_plan

  install_packages
  apply_selected_components "$repo_root"
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
