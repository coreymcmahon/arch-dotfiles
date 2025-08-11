# Arch Dotfiles

## Install Stow

```
sudo pacman -s stow
```

## Symlink configs

```
stow -t ~ alacritty
stow -t ~ bash
stow -t ~ hypr
# stow -t ~ kitty # If you want to use Kitty instead of Alacritty
stow -t ~ nvim
stow -t ~ waybar
```