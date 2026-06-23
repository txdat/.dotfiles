[ -f ~/.env ] && source ~/.env

#export TERM="xterm-256color"
export EDITOR="vim --clean"

# set prompt
function _git_branch() {
    git branch 2> /dev/null | sed -n -e 's/^\* \(.*\)/\1 /p'
}

setopt PROMPT_SUBST
export PROMPT='%F{green}%n@%m%f %F{blue}%~%f%F{white} $(_git_branch)%f❯ '

# history
HISTFILE=~/.zsh_history
HISTSIZE=3000
SAVEHIST=3000
setopt append_history
setopt extended_history
setopt hist_expire_dups_first
setopt hist_find_no_dups
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify
# setopt inc_append_history
setopt share_history

# completion
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# fpath=(~/.zsh/zsh-completions/src $fpath)

autoload -Uz compinit
if [[ -n "${ZDOTDIR:-$HOME}/.zcompdump"(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi
# autoload -Uz bashcompinit && bashcompinit

zstyle ':completion:*' matcher-list "m:{a-z}={A-Z}"
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

source <(kubectl completion zsh)

# highlighting
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# keybindings
# bindkey '^P' history-search-backward
# bindkey '^N' history-search-forward
bindkey '^[[A' history-search-backward # up
bindkey '^[[B' history-search-forward # down
bindkey '^I' complete-word # tab | complete
bindkey '^[[Z' autosuggest-accept # shift + tab | autosuggest
bindkey -v '^?' backward-delete-char # backspace in vi mode

# fzf
export FZF_DEFAULT_OPTS="
 --ansi
 --multi
 --no-separator
 --scrollbar=''
 --info=inline-right
 --height=100%
 --layout=reverse
 --border=none
 --highlight-line
 --pointer=󰁕
 --marker=▶
 --preview-window=hidden:noborder
 --bind=ctrl-p:toggle-preview,alt-w:toggle-preview-wrap,alt-j:preview-page-down,alt-k:preview-page-up
"

# conda
CONDA_HOME="$HOME/.miniconda3"

if [[ -n "$CONDA_HOME" ]]; then
    export PATH="$CONDA_HOME/bin:$PATH"

    conda() {
        unfunction conda
        __conda_setup="$("$CONDA_HOME/bin/conda" 'shell.zsh' 'hook' 2>/dev/null)"
        if [ $? -eq 0 ]; then
            eval "$__conda_setup"
        elif [ -f "$CONDA_HOME/etc/profile.d/conda.sh" ]; then
            . "$CONDA_HOME/etc/profile.d/conda.sh"
        fi
        unset __conda_setup
        conda "$@"
    }
fi

export QT_QPA_PLATFORM=xcb

export PATH="$HOME/.local/bin:$PATH"

# rust
export PATH="$HOME/.cargo/env:$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH"

# go
export PATH="$HOME/go/bin:$PATH"

# javascript
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi

# gcloud
export PATH="$HOME/.google-cloud-sdk/bin:$PATH"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
if [ -f "$HOME/.google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/.google-cloud-sdk/path.zsh.inc"; fi
if [ -f "$HOME/.google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/.google-cloud-sdk/completion.zsh.inc"; fi

# kubernetes
export KUBECONFIG=$HOME/.kube/config

# claude
export CLAUDE_CODE_ENABLE_TELEMETRY=0
# export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
# export CLAUDE_CODE_DISABLE_1M_CONTEXT=1
export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
export CLAUDE_CODE_SUBAGENT_MODEL="sonnet"
export CLAUDE_CODE_EFFORT_LEVEL="high"
export ENABLE_CLAUDEAI_MCP_SERVERS=false

alias claude1="ANTHROPIC_AUTH_TOKEN=$(echo $CLAUDE1_AUTH_TOKEN) claude"
alias deepseek="CLAUDE_CONFIG_DIR='$HOME/.claude-deepseek' ANTHROPIC_BASE_URL='https://api.deepseek.com/anthropic' ANTHROPIC_API_KEY=$(echo $DEEPSEEK_API_KEY) ANTHROPIC_MODEL='deepseek-v4-pro[1m]' ANTHROPIC_DEFAULT_OPUS_MODEL='deepseek-v4-pro[1m]' ANTHROPIC_DEFAULT_SONNET_MODEL='deepseek-v4-pro[1m]' ANTHROPIC_DEFAULT_HAIKU_MODEL='deepseek-v4-flash[1m]' claude"

alias k=kubectl
complete -o default -F __start_kubectl k

alias ls="ls --color"
alias xsc="xclip -sel c" # copy stdout to clipboard
alias xfc="xclip -sel c < " # copy data from file to clipboard
alias xcf="xclip -sel c -o > " # copy data from clipboard to file
alias tlmgr="/usr/share/texmf-dist/scripts/texlive/tlmgr.pl --usermode"

update_zsh () {
    dir=$(pwd)

    ZSH_PLUGINS=(
        'zsh-syntax-highlighting'
        'zsh-autosuggestions'
        'zsh-completions'
    )
    for plg in "${ZSH_PLUGINS[@]}"
    do
        cd ~/.zsh/$plg && git pull
    done

    cd $dir
}

# update_system() {
#   local ignore_packages=""

#   if [[ "$1" != "--no-skip" ]]; then
#     local pattern="^(linux|systemd|nvidia|cuda|cudnn)($|-)"
#     ignore_packages=$(pacman -Qq | grep -E "$pattern" | paste -sd, -)
#   fi

#   if [[ -n "$ignore_packages" ]]; then
#     sudo pacman -Syyu --ignore "$ignore_packages" && paru -Syyu --ignore "$ignore_packages"
#   else
#     sudo pacman -Syyu && paru -Syyu
#   fi
#   flatpak update
# }
