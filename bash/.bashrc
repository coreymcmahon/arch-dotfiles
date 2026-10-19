###
# Interactive-shell settings. Login-shell exports live in .bash_profile.
# Mirrors zsh/.zshrc in macos-dotfiles so aliases stay in parity.

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

###
# Secrets
# - Add sensitive aliases/functions to ~/.bashrc.secrets (git-ignored, created
#   with mode 600 by the dotfiles stage). Exports go in ~/.bash_profile.secrets.
if [ -f "$HOME/.bashrc.secrets" ]; then
    source "$HOME/.bashrc.secrets"
fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

###
# SSH agent provided by gnome-keyring/gcr (gcr-ssh-agent.socket, enabled by the services stage)
if [ -z "${SSH_AUTH_SOCK:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gcr/ssh" ]; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gcr/ssh"
fi

###
# GPG: let pinentry find the terminal
GPG_TTY=$(tty)
export GPG_TTY

###
# mise (manages Node.js, PHP and Go; installed by the development stage)
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi

###
# Aliases
# Misc.
alias q="exit"
alias ss="TERM=xterm-256color ssh"   # for hosts without the ghostty terminfo (iproute2's ss is still available as \ss)
killdns() {                           # flush the local DNS cache (systemd-resolved only; NetworkManager alone has no cache)
    if command -v resolvectl >/dev/null 2>&1; then sudo resolvectl flush-caches; else echo "no local DNS cache to flush"; fi
}
# Git
alias g=git
alias ga="git add"
alias gd="git diff"
alias gdc="git diff --cached"
alias gc="git commit"
alias gch="git checkout"
alias gs="git status"
alias gb="git branch -v"
alias pull="git pull --no-rebase origin"
alias push="git push origin"
pullc() { git pull --no-rebase origin "$(git rev-parse --abbrev-ref HEAD)"; }
pushc() { git push origin "$(git rev-parse --abbrev-ref HEAD)"; }
alias co="git checkout"
# PHP/Laravel
alias s="./vendor/bin/sail"
alias art="php artisan"
# JS
alias ni="npm install"
alias nrd="npm run dev"
# Neovim
alias vi="nvim"
alias vim="nvim"
