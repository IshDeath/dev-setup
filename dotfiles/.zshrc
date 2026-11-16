# ~/.zshrc — managed by dev-setup (symlinked from the repo by scripts/install.sh)

# ssh-agent via keychain. Must run BEFORE p10k instant prompt, since it may ask
# for a passphrase. Only loads the key if it exists.
if command -v keychain >/dev/null && [[ -f ~/.ssh/id_ed25519_github ]]; then
  eval "$(keychain --eval --quiet id_ed25519_github)"
fi

# Powerlevel10k instant prompt. Keep near the top. Anything that needs console
# input (password prompts, [y/n] confirmations, etc.) must go above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git docker)
source $ZSH/oh-my-zsh.sh

export LS_COLORS="rs=0:no=00:mi=00:mh=00:ln=01;36:or=01;31:di=01;34:ow=04;01;34:st=34:tw=04;34:pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32:"

# PATH additions
[[ -d /opt/nvim-linux-x86_64/bin ]] && export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
[[ -d $HOME/.local/bin ]] && export PATH="$HOME/.local/bin:$PATH"

# Machine-specific stuff (work aliases, tokens, etc.) — not tracked in git
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Prompt config. To customize: run `p10k configure`, then copy ~/.p10k.zsh back
# into the repo (or edit the symlinked file directly).
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
