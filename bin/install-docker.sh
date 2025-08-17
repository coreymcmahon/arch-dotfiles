#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Sy --needed \
  docker docker-compose

systemctl enable --now docker.service

# Add current user to docker group if not already
if ! id -nG "$SUDO_USER" | grep -qw docker; then
  usermod -aG docker "$SUDO_USER"
  echo "User $SUDO_USER added to docker group. You may need to log out/in."
fi

