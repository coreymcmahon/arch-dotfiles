#!/usr/bin/env bash

set -euo pipefail

###
# Install core dependencies
sudo pacman -Sy --needed base-devel git sudo neovim nano wget curl \
  man-db man-pages tree htop unzip zip tar \
  openssh rsync whois \
  bash-completion alacritty btop \
  docker docker-compose \
  re2c gd oniguruma \
  postgresql-libs

###
# Install yay
if command -v yay &>/dev/null; then
    echo "yay is already installed."
else
    echo "yay not found. Installing yay from AUR..."

    # Create a temp directory
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    # Clone yay from AUR
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"

    # Build and install
    cd "$tmpdir/yay"
    makepkg -si --noconfirm
fi

###
# Fonts
yay -S --noconfirm --needed \
  ttf-font-awesome ttf-cascadia-mono-nerd ttf-ia-writer \
  noto-fonts noto-fonts-emoji ttf-jetbrains-mono \
  noto-fonts-cjk noto-fonts-extra

###
# Hyprland
yay -S --noconfirm --needed \
  hyprland hyprshot hyprpicker hyprlock \
  hypridle hyprsunset polkit-gnome hyprland-qtutils \
  walker-bin libqalculate waybar mako swaybg swayosd walker-bin \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

###
# Mise
sudo pacman -Sy --needed mise
# Node
mise install node@lts
mise use --global node@lts
# PHP
mise install php@latest
mise use --global php@latest
# Go
mise install go@latest
mise use --global go@latest
# Activate
if ! grep -Fxq 'eval "$(mise activate bash)"' ~/.bashrc; then
  echo "Activating mise..."
  echo 'eval "$(mise activate bash)"' >> ~/.bashrc
fi


###
#
mkdir -p ~/Code/coreymcmahon
cd ~/Code/coreymcmahon
# Only clone if the repo directory doesn't already exist
if [ ! -d ~/Code/coreymcmahon/arch-dotfiles ]; then
  git clone git@github.com:coreymcmahon/arch-dotfiles.git ~/Code/coreymcmahon/arch-dotfiles
fi

echo 'Finished.'
