###
# Login-shell environment (read once at login, inherited by the Hyprland
# session and everything it starts). Mirrors zsh/.zshenv in macos-dotfiles.

###
# PATH
export PATH="$HOME/.local/bin:$PATH"

###
# Editor (aicommit, git, visudo)
export EDITOR=nvim VISUAL=nvim

###
# Secrets
# - Add export statements to ~/.bash_profile.secrets (e.g. NPM_TOKEN).
#   The file is git-ignored and created with mode 600 by the dotfiles stage.
if [ -f "$HOME/.bash_profile.secrets" ]; then
    source "$HOME/.bash_profile.secrets"
fi

[[ -f ~/.bashrc ]] && . ~/.bashrc
