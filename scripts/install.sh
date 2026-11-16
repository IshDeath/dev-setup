#!/usr/bin/env bash
# Bootstrap a fresh Debian (trixie) WSL install.
# Safe to re-run: every step checks whether it's already done.
#
#   ./scripts/install.sh                 # everything except optional bits
#   ./scripts/install.sh --with-nvim     # also install latest Neovim + LazyVim starter
#   ./scripts/install.sh --skip-php      # skip PHP packages
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WITH_NVIM=0
SKIP_PHP=0
for arg in "$@"; do
  case "$arg" in
    --with-nvim) WITH_NVIM=1 ;;
    --skip-php)  SKIP_PHP=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

step "Base packages"
sudo apt update
sudo apt upgrade -y
sudo apt install -y \
  ca-certificates curl git zsh keychain vim htop build-essential \
  ripgrep fd-find unzip fontconfig

if [[ $SKIP_PHP -eq 0 ]]; then
  step "PHP 8.4"
  # Note: on trixie the redis extension is `php-redis`, not `php8.4-redis`.
  sudo apt install -y \
    php8.4-cli php8.4-common php8.4-mysql php8.4-pgsql php8.4-odbc php8.4-curl \
    php8.4-mbstring php8.4-xml php8.4-zip php8.4-bcmath php8.4-intl php8.4-gd \
    php8.4-soap php8.4-opcache php-redis
fi

step "Docker Engine"
if ! command -v docker >/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "docker already installed: $(docker --version)"
fi
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  echo "Added $USER to docker group (takes effect after 'wsl --shutdown' + reopen)."
fi

step "Oh My Zsh"
if [[ ! -d $HOME/.oh-my-zsh ]]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

step "Powerlevel10k"
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ ! -d $P10K_DIR ]]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

step "Dotfiles (symlinked from $REPO_DIR/dotfiles)"
for f in .zshrc .p10k.zsh; do
  target="$HOME/$f"
  if [[ -e $target && ! -L $target ]]; then
    mv "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
    echo "Backed up existing $f"
  fi
  ln -sfn "$REPO_DIR/dotfiles/$f" "$target"
done

step "Default shell -> zsh"
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
  sudo chsh -s "$(command -v zsh)" "$USER"
fi

if [[ $WITH_NVIM -eq 1 ]]; then
  step "Neovim (latest release; apt's version is too old for LazyVim)"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/nvim.tar.gz" https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
  sudo rm -rf /opt/nvim-linux-x86_64
  sudo tar -C /opt -xzf "$tmp/nvim.tar.gz"
  rm -rf "$tmp"
  if [[ ! -d $HOME/.config/nvim ]]; then
    git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
  fi
fi

cat <<'EOF'

Done. Remaining manual steps (see README):
  1. Set up SSH keys + add the public key to GitHub
  2. Set git user.name / user.email
  3. From PowerShell: wsl --shutdown, then reopen Debian (picks up zsh + docker group)
  4. Verify: docker run hello-world
EOF
