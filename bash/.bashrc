#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

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

