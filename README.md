# dev-setup

My reproducible developer setup for Windows + **Debian (trixie) on WSL 2**:
Docker Engine, PHP 8.4, zsh + Oh My Zsh + Powerlevel10k (with my saved prompt config),
SSH keys for GitHub, and optionally Neovim/LazyVim.

Started from [kmtiredevelopment/setup-developer](https://github.com/kmtiredevelopment/setup-developer).
These are the steps that actually worked on Debian 13. What I changed:

| Original guide | What actually works on Debian trixie |
|---|---|
| Docker GPG key from `.../linux/ubuntu/gpg` saved to `/usr/share/keyrings/docker-archive-keyring.gpg`, while the Debian repo line pointed at `/etc/apt/keyrings/docker.asc` | Download `.../linux/debian/gpg` to `/etc/apt/keyrings/docker.asc` so the key path matches the repo line |
| `apt install software-properties-common apt-transport-https` | Debian 13 doesn't have `software-properties-common`, and you don't need it. Install `ca-certificates curl` only |
| `php8.4-redis` | That package doesn't exist. Use `php-redis` |
| PHP install before `apt update` | Run `apt update && apt upgrade` first |
| `sudo groupadd docker` | The docker package creates the group itself |
| Log out and back in to pick up the docker group | Run `wsl --shutdown` from PowerShell, then reopen |
| RSA key via plain `ssh-keygen` | A separate ed25519 key for GitHub, an `~/.ssh/config` entry, and `keychain` so you type the passphrase once per boot |
| Copy fonts to `~/.fonts` in WSL | Not needed. Windows Terminal draws the text, so the fonts only have to be installed on Windows |
| `p10k configure` on every machine | My config is saved in `dotfiles/.p10k.zsh` and gets symlinked in |
| — | Transient prompt is turned off in my p10k config |
| — | Neovim from apt is too old for LazyVim. Use the release tarball in `/opt` |

---

## Quick start (new machine)

```powershell
# 1. PowerShell (admin): install WSL + Debian, then reboot
wsl --install --web-download -d Debian

# 2. PowerShell (normal user): fonts, then set the Windows Terminal font (see Fonts section)
git clone https://github.com/IshDeath/dev-setup.git $HOME\dev-setup
powershell -ExecutionPolicy Bypass -File $HOME\dev-setup\scripts\install-fonts.ps1
```

```bash
# 3. Inside Debian: clone into the Linux filesystem (not /mnt/c, which is slow) and run the installer
sudo apt update && sudo apt install -y git
git clone https://github.com/IshDeath/dev-setup.git ~/dev-setup
~/dev-setup/scripts/install.sh            # add --with-nvim for Neovim/LazyVim, --skip-php to skip PHP
```

```powershell
# 4. PowerShell: restart WSL so the new default shell and docker group take effect
wsl --shutdown
```

5. Reopen Debian, then do [SSH keys](#ssh-keys) and [git identity](#git-identity) by hand.
6. Check it: `docker run hello-world`, `ssh -T git@github.com`.

> If the repo is private, the HTTPS clones in steps 2 and 3 will ask you to sign in.
> Use a GitHub personal access token as the password, or download the repo as a zip.

The installer is safe to re-run. It skips anything already installed and backs up an existing `~/.zshrc` or `~/.p10k.zsh` before it symlinks the repo's copies.

---

## 1. Install WSL

Requires Windows 10 2004+ (build 19041+) or Windows 11.

> **BitLocker:** if the machine uses BitLocker, have the recovery key ready before you start. The reboot may ask for it.

From an **admin** PowerShell:

```powershell
wsl --install --web-download -d Debian
```

Reboot. If the install fails, run `wsl --update --web-download` and try again.
On a work machine, you may need to do this step logged in as your admin account.

Check the version with `wsl -v`. It should say WSL 2.x. If not, run `wsl --set-default-version 2`.

**From here on, use a normal (non-admin) terminal.** When Debian first launches, it asks you to create a UNIX username and password.

Debian trixie on WSL ships `/etc/wsl.conf` with `systemd=true`. Docker needs systemd, so check it's there:

```bash
cat /etc/wsl.conf
# [boot]
# systemd=true
```

## 2. Base packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl git zsh keychain vim htop build-essential ripgrep fd-find unzip
```

### PHP 8.4

Debian 13 ships PHP 8.4, so you don't need an extra repo:

```bash
sudo apt install -y php8.4-cli php8.4-common php8.4-mysql php8.4-pgsql php8.4-odbc php8.4-curl \
  php8.4-mbstring php8.4-xml php8.4-zip php8.4-bcmath php8.4-intl php8.4-gd php8.4-soap \
  php8.4-opcache php-redis
php -v
```

## 3. Docker Engine

This follows Docker's [official Debian instructions](https://docs.docker.com/engine/install/debian/):

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo docker run hello-world
sudo usermod -aG docker $USER
```

Then run `wsl --shutdown` from PowerShell and reopen Debian. After that, `docker ps` should work without sudo.

Private registry (work):

```bash
docker login registry.kmdevlab.com
```

## SSH keys

Use a **separate key for each machine and each purpose**. Never commit private keys to this repo. `.gitignore` blocks `id_*` as a backstop.

### GitHub key

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)-github" -f ~/.ssh/id_ed25519_github
cat ~/.ssh/id_ed25519_github.pub
```

Use a passphrase. `keychain` (below) means you only type it once per boot.

Add the public key on GitHub: **Settings → SSH and GPG keys → New SSH key**, paste it, and save.

Tell ssh to use that key for GitHub:

```bash
cat >> ~/.ssh/config <<'EOF'

Host github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config
ssh -T git@github.com     # "Hi <user>! You've successfully authenticated..."
```

`dotfiles/.zshrc` already starts `keychain` for `id_ed25519_github` when that file exists. If you're in bash, add this to `~/.bashrc`:

```bash
eval "$(keychain --eval --quiet id_ed25519_github)"
```

Once the key works, switch this repo's remote to SSH:

```bash
git -C ~/dev-setup remote set-url origin git@github.com:IshDeath/dev-setup.git
```

### Two GitHub accounts on one machine (work + personal)

Give the second account its own key and host alias:

```
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
```

Then clone with `git clone git@github-personal:IshDeath/dev-setup.git`.

### Reusing existing keys from Windows (work machine)

If the Windows side already has server keys and an ssh config:

```bash
cp /mnt/c/Users/<WindowsUser>/.ssh/{config,known_hosts} ~/.ssh/
cp /mnt/c/Users/<WindowsUser>/.ssh/id_* ~/.ssh/
rm -f ~/.ssh/*.ppk                     # PuTTY keys are useless here
chmod 700 ~/.ssh
chmod 600 ~/.ssh/*
chmod 644 ~/.ssh/*.pub
```

Linux ssh refuses to use keys whose permissions are too open. That's why the `chmod` lines are there.

### Copying a key to a server

```bash
ssh-copy-id -i ~/.ssh/<key>.pub user@host   # needs password SSH access the first time
ssh user@host                               # should now log in with the key
```

## Git identity

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
```

## 4. zsh, Oh My Zsh, Powerlevel10k

`scripts/install.sh` does all of this. Here are the manual steps:

```bash
sudo apt install -y zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"   # answer Y to change shell
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# use the saved configs from this repo
ln -sfn ~/dev-setup/dotfiles/.zshrc    ~/.zshrc
ln -sfn ~/dev-setup/dotfiles/.p10k.zsh ~/.p10k.zsh
exec zsh
```

### Fonts

The MesloLGS NF fonts (from [powerlevel10k](https://github.com/romkatv/powerlevel10k#fonts)) are in `fonts/`.

- **Windows:** run `scripts\install-fonts.ps1`, or double-click each `.ttf` and click Install.
- **Windows Terminal:** go to Settings → Defaults (or the Debian profile) → Appearance → Font face, choose **MesloLGS NF**, and save.
- **Inside WSL:** nothing to do. The terminal draws the text on the Windows side.

### My prompt config

`dotfiles/.p10k.zsh` was made with the wizard using: nerdfont-v3 + powerline, small icons, classic, unicode, dark,
12h time, angled separators, round heads, flat tails, 1 line, sparse, many icons, concise, instant prompt verbose.
**Transient prompt is off.**

To change it, run `p10k configure`. Because `~/.p10k.zsh` is a symlink into the repo, the wizard may replace the symlink with a regular file. Copy it back and commit:

```bash
cp ~/.p10k.zsh ~/dev-setup/dotfiles/.p10k.zsh   # only if it's no longer a symlink
ln -sfn ~/dev-setup/dotfiles/.p10k.zsh ~/.p10k.zsh
cd ~/dev-setup && git commit -am "Update p10k config" && git push
```

Put machine-specific shell settings (work aliases, env vars, tokens) in `~/.zshrc.local`. The tracked `.zshrc` sources it, and git ignores it.

## 5. Optional: Neovim + LazyVim

The Neovim in apt is too old for LazyVim. Install the latest release into `/opt` instead (`install.sh --with-nvim` does this):

```bash
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
rm nvim-linux-x86_64.tar.gz

git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
```

`.zshrc` already adds `/opt/nvim-linux-x86_64/bin` to `PATH`. LazyVim also wants `build-essential`, `ripgrep` and `fd-find`, which the base packages step installs.

## Repo layout

```
dotfiles/.zshrc          zsh config (symlinked to ~/.zshrc)
dotfiles/.p10k.zsh       Powerlevel10k prompt config (symlinked to ~/.p10k.zsh)
fonts/                   MesloLGS NF Regular/Bold/Italic/Bold Italic
scripts/install.sh       Debian WSL bootstrap (re-runnable)
scripts/install-fonts.ps1  per-user Windows font install
```
