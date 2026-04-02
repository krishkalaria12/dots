<p align="center">
  <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=700&size=28&duration=3000&pause=1000&color=C8C8C8&center=true&vCenter=true&width=560&lines=%E3%80%8C%E2%9C%A6+NIRI+%2B+DMS+DOTFILES+%E2%9C%A6%E3%80%8D;%E3%80%8C%E2%9C%A6+MINIMAL+%C3%97+FUNCTIONAL+%E2%9C%A6%E3%80%8D" alt="Niri dotfiles typing banner" />
</p>

<p align="center">
  <img src="screenshots/main.png" alt="Main desktop view" width="100%" />
</p>

## Overview

personal linux dotfiles built around:

- `niri`
- `DankMaterialShell`
- `ghostty`
- `fish` / `zsh`
- `dolphin`
- `btop`
- `Sweet-cursors`
- `Inter` / `Iosevka`

the repo is being built incrementally and only tracks config that is stable and intentional.

### Search
>
> Launcher search, file search, and quick actions through DMS.

<p align="center">
  <img src="screenshots/search.png" alt="Launcher search" width="49%" />
  <img src="screenshots/file-search.png" alt="File search" width="49%" />
</p>

### Shell
>
> DankMaterialShell provides the launcher, controls, running apps, and settings surfaces.

<p align="center">
  <img src="screenshots/controls.png" alt="Control center" width="49%" />
  <img src="screenshots/settings.png" alt="DMS settings" width="49%" />
</p>

### Compositor
>
> Niri handles the tiled column workflow.

<p align="center">
  <img src="screenshots/niri.png" alt="Niri workspace view" width="100%" />
</p>

### Tools
>
> Extra tooling and terminal workflow.

<p align="center">
  <img src="screenshots/process.png" alt="Btop process view" width="100%" />
</p>

### Theme Palette
>
> Dynamic colors and shell styling across the setup.

<p align="center">
  <img src="screenshots/theme-1.png" alt="Theme preview 1" width="49%" />
  <img src="screenshots/theme-2.png" alt="Theme preview 2" width="49%" />
</p>
<p align="center">
  <img src="screenshots/theme-3.png" alt="Theme preview 3" width="49%" />
  <img src="screenshots/theme-4.png" alt="Theme preview 4" width="49%" />
</p>

## Installation

manual setup is recommended for now.

1. Install the core packages you want.

```bash
sudo pacman -S --needed niri ghostty dolphin fish zsh btop wl-clipboard grim slurp brightnessctl hyprpicker fastfetch starship zoxide papirus-icon-theme qt5ct qt6ct
yay -S dms-shell-git zed zen-browser-bin
```

2. Clone the repo.

```bash
git clone https://github.com/krishkalaria12/dots ~/dotfiles
```

3. Copy the tracked config into place.

```bash
mkdir -p ~/.config ~/.local/bin ~/.local/share/fonts ~/.local/share/icons
cp -r ~/dotfiles/home/. ~/
cp -r ~/dotfiles/config/{DankMaterialShell,btop,fish,ghostty,niri,qt5ct,qt6ct} ~/.config/
cp ~/dotfiles/config/{dolphinrc,kdeglobals} ~/.config/
cp -r ~/dotfiles/config/fonts/. ~/.local/share/fonts/
cp -r ~/dotfiles/config/icons/. ~/.local/share/icons/
cp -r ~/dotfiles/local/bin/. ~/.local/bin/
chmod +x ~/.local/bin/*
fc-cache -fv
```

4. Restart your session, then enable user services if needed.

```bash
systemctl --user daemon-reload
systemctl --user enable --now dms.service
```

> [!NOTE]
> This repo is still evolving. Wallpapers and larger visual assets are intentionally being added later instead of being dumped in all at once.

## Structure

```text
.
├── config
│   ├── btop
│   ├── DankMaterialShell
│   ├── dolphinrc
│   ├── fish
│   ├── fonts
│   ├── ghostty
│   ├── icons
│   ├── kdeglobals
│   ├── niri
│   ├── qt5ct
│   └── qt6ct
├── home
│   ├── .gitconfig
│   ├── .profile
│   └── .zshrc
├── install
├── local
│   └── bin
│       └── niri-screenshot-select.sh
└── screenshots
```

## Notes

- this is a curated repo, not a raw backup of `~/.config`
- machine junk, caches, and generated state stay out unless they are intentionally part of the setup
- wallpapers and larger assets will be added in later passes
