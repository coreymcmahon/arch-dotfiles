###
# Secrets
# - Add sensitive aliases etc. to .bashrc.secrets
if [ -f "$HOME/.bashrc.secrets" ]; then
    source "$HOME/.bashrc.secrets"
fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

###
# mise (manages Node.js, PHP and Go; installed by the development stage)
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi

###
# Variables and settings used in interactive shells

# Aliases
alias q="exit"
# Git
alias g=git
alias ga="git add"
alias gd="git diff"
alias gdc="git diff --cached"
alias gc="git commit"
alias gs="git status"
alias pull="git pull --no-rebase origin"
alias push="git push origin"
alias co="git checkout"
# PHP/Laravel
alias s="./vendor/bin/sail"
# JS
alias ni="npm install"
alias nrd="npm run dev"
# Neovim
alias vi="nvim"
alias vim="nvim"

