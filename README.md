# dev-setup

My reproducible developer environment for Windows 11 plus **Debian (trixie) on WSL 2**.

- **Windows:** apps via winget, VS Code config and extensions, Windows Terminal settings, MesloLGS NF fonts, Python packages, git defaults
- **Debian WSL:** Docker Engine, PHP 8.4, zsh + Oh My Zsh + Powerlevel10k (with my saved prompt config), SSH keys for GitHub, and optionally Neovim/LazyVim

---

## Quick start (new machine)

```powershell
# 1. Admin PowerShell: install WSL + Debian, then reboot
wsl --install --web-download -d Debian
```

```powershell
# 2. Normal PowerShell: get the repo (winget ships with Windows 11) and set up the Windows side
winget install -e --id Git.Git
# open a new terminal so git is on PATH
git clone https://github.com/IshDeath/dev-setup.git $HOME\dev-setup
powershell -ExecutionPolicy Bypass -File $HOME\dev-setup\scripts\install-windows.ps1          # add -Work on a work machine
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

5. Reopen Debian. Do [SSH keys](#ssh-keys) by hand, then sign in to `gh auth login` and `claude`. If you use Claude Code inside WSL too, see [Claude Code config](#claude-code-config).
6. Check it: `docker run hello-world`, `ssh -T git@github.com`.

Both installers are safe to re-run. Already-installed items are skipped, and existing config files are backed up (`*.bak.<timestamp>`) before they're replaced.

---

## Windows

### What `install-windows.ps1` installs

| Group | Apps (winget IDs) |
|---|---|
| Shell / terminal | `Microsoft.WindowsTerminal`, `Microsoft.PowerShell`, `Microsoft.WSL` |
| Source control | `Git.Git`, `GitHub.cli` |
| Editors / AI | `Microsoft.VisualStudioCode`, `Anthropic.ClaudeCode`, `Anthropic.Claude` |
| Languages | `Python.Python.3.12`, `OpenJS.NodeJS.LTS`, `EclipseAdoptium.Temurin.21.JDK`, `PHP.PHP.8.4` |
| CLI tools | `BurntSushi.ripgrep.MSVC` |
| Database | `DBeaver.DBeaver.Community` |
| Remote access | `PuTTY.PuTTY`, `WinSCP.WinSCP`, `mRemoteNG.mRemoteNG` |
| Network | `Insecure.Nmap`, `WiresharkFoundation.Wireshark` |
| Utilities | `Microsoft.PowerToys` |
| `-Work` only | `Oracle.JavaRuntimeEnvironment` (Java 8), `ApacheFriends.Xampp.8.2`, PS modules `ExchangeOnlineManagement` + `Microsoft.Graph.Authentication`, plus everything in [Work laptop: AS400 / DBeaver](#work-laptop-as400--dbeaver) |

The scripts run under the built-in Windows PowerShell 5.1 (`powershell -File ...`), so they work on a fresh machine before PowerShell 7 is installed. They install PowerShell 7 (`pwsh`) as part of the core apps.

It also:

- installs the fonts in `fonts/` for your user (`install-fonts.ps1`)
- copies `vscode/settings.json` and `vscode/keybindings.json` to `%APPDATA%\Code\User\`
- installs every extension listed in `vscode/extensions.txt`
- copies `windows/terminal-settings.json` into Windows Terminal (Ottosson color scheme; MesloLGS NF on the Debian profile)
- restores PowerToys settings from `windows/powertoys/` with `scripts/powertoys.ps1 -Import`: general settings plus each module's settings (FancyZones, Peek, Awake, PowerRename, mouse utilities…). FancyZones' applied layouts are skipped because they're tied to a machine's monitors
- runs `pip install --user -r windows/requirements.txt` for Python 3.12
- sets git `core.editor "code --wait"`, `init.defaultBranch main`, and `pull.rebase false`, and asks for `user.name` and `user.email` if they aren't set

- installs **Sysmon** with the [SwiftOnSecurity config](windows/sysmon/README.md) (`scripts/install-sysmon.ps1`, UAC prompt). If Sysmon is already installed, it updates the config in place
- clones the private repos `IshDeath/claude-config` and `IshDeath/maddenco-docs` into `$HOME` and runs `claude-config\install.ps1` (see [Claude Code config](#claude-code-config))

Flags: `-Work`, `-SkipApps` (config only), `-SkipConfig` (don't touch VS Code or Terminal settings), `-SkipClaudeConfig`, `-SkipSysmon`.

### Claude Code config

My skills, OneNote scripts, hooks, settings and global `CLAUDE.md` live in the **private** repo [IshDeath/claude-config](https://github.com/IshDeath/claude-config). The MaddenCo docs live in the private repo [IshDeath/maddenco-docs](https://github.com/IshDeath/maddenco-docs). On Windows, `install-windows.ps1` clones both and runs the installer. The first clone asks you to sign in to GitHub as IshDeath.

After that, on each machine:

- run `powershell.exe -NoProfile -File $HOME\.claude\scripts\onenote\list_sections.ps1` and set `ONENOTE_DOC_SECTION_ID` (see the claude-config README)
- fill in `$HOME\maddenco-docs\.env` with the AS400 host and read-only credentials if you need `query_as400.py`

Inside WSL, once SSH keys are set up:

```bash
curl -fsSL https://claude.ai/install.sh | bash        # Claude Code
git clone git@github.com:IshDeath/claude-config.git ~/claude-config
git clone git@github.com:IshDeath/maddenco-docs.git ~/maddenco-docs
~/claude-config/install.sh
```

### Manual installs (not on winget)

- **Xshell 8** (NetSarang)
- **Work:** IBM Data Server Client
- **Work, PHP on Windows:** the `php_ibm_db2.dll` extension. Copy it into PHP's `ext\` folder and add `extension=php_ibm_db2.dll` to `php.ini`. It needs the IBM Data Server Client.

### Work laptop: AS400 / DBeaver

`scripts/install-work.ps1` runs as part of `install-windows.ps1 -Work`. You can also run it on its own. It sets up:

| Piece | How |
|---|---|
| **JTOpen JDBC jar** (`jt400-21.0.6.jar`) | Downloads it from Maven Central into `C:\ITFiles\JTOpen`, checks the SHA1, and sets the user env var `AS400_JAR` (`query_as400.py` reads it) |
| **IBM i Access ODBC Driver** | Installs it silently from `Image64a\cwbinstall.msi` inside the IBM zip you pass with `-OdbcZip` |
| **IBM i Access Client Solutions** | Runs `install_acs_64_allusers.js` from the ACS zip you pass with `-AcsZip` (uses Java from Temurin 21) |
| **DBeaver connections** | Fills in `work/dbeaver/data-sources.template.json` (AS400 + MySQL) with the hosts you enter, and writes it to DBeaver's workspace. No passwords are stored; DBeaver asks on first connect and downloads its own drivers |
| **Python** | `pyodbc`, `JayDeBeApi` and `JPype1` are in `windows/requirements.txt` |

The IBM installers are licensed and need an IBM ID, so they are **not** in this repo. Download them from
<https://www.ibm.com/support/pages/ibm-i-access-client-solutions> ("IBM i Access Client Solutions" and
"IBM i Access - Windows Application Package"), then:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-work.ps1 `
  -OdbcZip "$HOME\Downloads\IBMiAccess_v1r1_WindowsAP_English.zip" `
  -AcsZip  "$HOME\Downloads\<ACS zip>.zip" `
  -As400Host <ip> -MysqlHost <ip> -MysqlDb <db>
```

Anything you leave out is skipped or prompted for. Steps that are already done (driver installed, ACS present) are skipped. Close DBeaver before running it.

Hosts are placeholders in the template (`{{AS400_HOST}}` etc.). Don't commit real internal IPs here, because this repo is public.

### Keeping the Windows config in sync

When you change settings on a machine, copy them back into the repo and commit:

```powershell
cd $HOME\dev-setup
code --list-extensions | Set-Content vscode\extensions.txt
Copy-Item $env:APPDATA\Code\User\settings.json, $env:APPDATA\Code\User\keybindings.json vscode\
Copy-Item "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json" windows\terminal-settings.json
powershell -ExecutionPolicy Bypass -File scripts\powertoys.ps1 -Export
git diff        # check that no machine-specific paths, IPs or hostnames crept in
```

Keep machine- or work-specific VS Code settings (Code for IBM i connections, UNC hosts, Remote-SSH hosts) out of the repo's `settings.json`.

---

## Debian WSL

### 1. Install WSL

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

Docker needs systemd. Debian trixie on WSL enables it in `/etc/wsl.conf`, so check it's there:

```bash
cat /etc/wsl.conf
# [boot]
# systemd=true
```

### 2. Base packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl git zsh keychain vim htop build-essential ripgrep fd-find unzip
```

#### PHP 8.4

Debian 13 ships PHP 8.4, so you don't need an extra repo. The redis extension is `php-redis`; there is no `php8.4-redis`.

```bash
sudo apt install -y php8.4-cli php8.4-common php8.4-mysql php8.4-pgsql php8.4-odbc php8.4-curl \
  php8.4-mbstring php8.4-xml php8.4-zip php8.4-bcmath php8.4-intl php8.4-gd php8.4-soap \
  php8.4-opcache php-redis
php -v
```

### 3. Docker Engine

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

### SSH keys

Use a **separate key for each machine and each purpose**. Never commit private keys to this repo. `.gitignore` blocks `id_*` as a backstop.

#### GitHub key

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

#### Two GitHub accounts on one machine (work + personal)

Give the second account its own key and host alias:

```
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
```

Then clone with `git clone git@github-personal:IshDeath/dev-setup.git`.

On Windows, HTTPS remotes in the form `https://IshDeath@github.com/IshDeath/<repo>.git` make Git Credential Manager use the personal login. `gh auth switch --user IshDeath` (or `--user IDeathe`) switches the gh CLI account.

#### Reusing existing keys from Windows (work machine)

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

#### Copying a key to a server

```bash
ssh-copy-id -i ~/.ssh/<key>.pub user@host   # needs password SSH access the first time
ssh user@host                               # should now log in with the key
```

### Git identity (WSL)

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
```

### 4. zsh, Oh My Zsh, Powerlevel10k

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

#### Fonts

The MesloLGS NF fonts (from [powerlevel10k](https://github.com/romkatv/powerlevel10k#fonts)) are in `fonts/`. Install them on **Windows**, not inside WSL, because the terminal draws the text on the Windows side. `install-windows.ps1` installs them and sets the Terminal font. To do it by hand, double-click each `.ttf`, then in Windows Terminal go to Settings → Debian profile → Appearance → Font face and choose **MesloLGS NF**.

#### My prompt config

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

### 5. Optional: Neovim + LazyVim

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

---

## Repo layout

```
scripts/install-windows.ps1   Windows bootstrap: winget apps, fonts, VS Code, Terminal, Python, git
scripts/install-fonts.ps1     per-user font install (called by install-windows.ps1)
scripts/install-work.ps1      work extras: JTOpen jar, IBM i Access ODBC + ACS, DBeaver connections
scripts/powertoys.ps1         save (-Export) / restore (-Import) PowerToys settings
scripts/install-sysmon.ps1    install Sysmon / update its config (self-elevates)
windows/sysmon/               SwiftOnSecurity sysmon-config (CC BY 4.0)
windows/powertoys/            PowerToys settings (per-module JSON)
work/dbeaver/                 DBeaver connection template (placeholder hosts)
scripts/install.sh            Debian WSL bootstrap
vscode/settings.json          VS Code user settings (machine-specific entries removed)
vscode/keybindings.json       VS Code keybindings
vscode/extensions.txt         VS Code extensions, one ID per line
windows/terminal-settings.json  Windows Terminal settings
windows/requirements.txt      global Python packages
dotfiles/.zshrc               zsh config (symlinked to ~/.zshrc)
dotfiles/.p10k.zsh            Powerlevel10k prompt config (symlinked to ~/.p10k.zsh)
fonts/                        MesloLGS NF Regular/Bold/Italic/Bold Italic
```
