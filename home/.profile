export GOPATH="${GOPATH:-$HOME/.cache/go}"
export PATH="$HOME/.local/bin:$GOPATH/bin:$PATH"

if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim
elif command -v vim >/dev/null 2>&1; then
  export EDITOR=vim
else
  export EDITOR=vi
fi

if command -v zen-browser >/dev/null 2>&1; then
  export BROWSER=zen-browser
elif command -v firefox >/dev/null 2>&1; then
  export BROWSER=firefox
else
  export BROWSER=xdg-open
fi

export VISUAL="$EDITOR"
export TERMINAL=ghostty

export __GL_SHADER_DISK_CACHE_PATH="$HOME/.cache/nv"
export _JAVA_AWT_WM_NONREPARENTING=1
export QT_QPA_PLATFORMTHEME=kde
export KDE_SESSION_VERSION=6
export KDE_FULL_SESSION=true
