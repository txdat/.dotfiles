[ -f ~/.env ] && source ~/.env

#export TERM="xterm-256color"
export EDITOR="vim --clean"

# set prompt
function _git_branch() {
    local b
    b=$(git symbolic-ref --short HEAD 2>/dev/null) && echo -n "$b "
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

KUBECTL_COMPLETION="$HOME/.zsh/kubectl.completion.zsh"
if [[ ! -s "$KUBECTL_COMPLETION" ]]; then
    kubectl completion zsh > "$KUBECTL_COMPLETION" 2>/dev/null || true
fi
[[ -f "$KUBECTL_COMPLETION" ]] && source "$KUBECTL_COMPLETION"

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
 --preview-window=right:80%:noborder:hidden
 --bind=ctrl-p:toggle-preview,alt-w:toggle-preview-wrap,alt-j:preview-page-down,alt-k:preview-page-up
"

export PATH="$HOME/.local/bin:$PATH"

# gcloud (installed via dnf — /usr/bin/gcloud is already on PATH,
# no path.zsh.inc needed; only completion is sourced from the sdk dir)
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
if [ -f /usr/lib64/google-cloud-sdk/completion.zsh.inc ]; then
    source /usr/lib64/google-cloud-sdk/completion.zsh.inc
fi

# kubernetes
export KUBECONFIG=$HOME/.kube/config

alias k=kubectl
compdef k=kubectl

# python
CONDA_HOME="$HOME/miniconda3"

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

# rust
export PATH="$HOME/.cargo/env:$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH"

# go
export PATH="$HOME/go/bin:$PATH"

# nodejs
export PATH="$HOME/.local/share/fnm:$HOME/.local/share/fnm/aliases/default/bin/:$PATH"

# flutter
export PATH="$HOME/fvm/bin:$PATH"

export CHROME_EXECUTABLE=/usr/bin/google-chrome

claude() {
    local env_vars=(
        CLAUDE_CODE_ENABLE_TELEMETRY=0
        CLAUDE_CODE_AUTO_COMPACT_WINDOW=300000
        CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
        CLAUDE_CODE_DISABLE_AUTO_MEMORY=1
        CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=1
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
        CLAUDE_CODE_SUBAGENT_MODEL=sonnet
        ENABLE_LSP_TOOL=1
        ENABLE_CLAUDEAI_MCP_SERVERS=false
    )

    local args=()
    for arg in "$@"; do
        case "$arg" in
            --a1)
                env_vars+=("ANTHROPIC_AUTH_TOKEN=$CLAUDE1_API_KEY")
                ;;
            --ds)
                PRO_MODEL="deepseek-v4-pro"
                FLASH_MODEL="deepseek-v4.1-flash"
                env_vars+=(
                    "ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic"
                    "ANTHROPIC_AUTH_TOKEN=$DEEPSEEK_API_KEY"
                    "ANTHROPIC_DEFAULT_OPUS_MODEL=$PRO_MODEL[1m]"
                    "ANTHROPIC_DEFAULT_SONNET_MODEL=$FLASH_MODEL[1m]"
                    "ANTHROPIC_DEFAULT_HAIKU_MODEL=$FLASH_MODEL"
                    "CLAUDE_CODE_SUBAGENT_MODEL=$FLASH_MODEL"
                )
                ;;
            -d)
                args+=("--dangerously-skip-permissions")
                ;;
            *)
                args+=("$arg")
                ;;
        esac
    done
    env "${env_vars[@]}" command claude "${args[@]}"
}

agy() {
    local env_vars=()

    local args=()
    for arg in "$@"; do
        case "$arg" in
            -d)
                args+=("--dangerously-skip-permissions")
                ;;
            *)
                args+=("$arg")
                ;;
        esac
    done
    env "${env_vars[@]}" command agy "${args[@]}"
}

codex() {
    local env_vars=()

    local args=()
    for arg in "$@"; do
        case "$arg" in
            -d)
                args+=("--yolo")
                ;;
            *)
                args+=("$arg")
                ;;
        esac
    done
    env "${env_vars[@]}" command codex "${args[@]}"
}

xc() {
    case "$1" in
        -f|--file)
            shift
            xclip -selection clipboard < "$1"
            ;;
        -o|--out)
            shift
            if [ -n "$1" ]; then
                xclip -selection clipboard -o > "$1"
            else
                xclip -selection clipboard -o
            fi
            ;;
        *)
            xclip -selection clipboard "$@"
            ;;
    esac
}

update_zsh() {
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

    # regenerate cached kubectl completion after kubectl updates
    kubectl completion zsh > ~/.zsh/kubectl.completion.zsh 2>/dev/null

    cd $dir
}

update_sys() {
  grep -q '^ID=arch$' /etc/os-release || return 0

  local ignore_packages=""

  if [[ "$1" == "--skip" ]]; then
    local pattern="^(linux|systemd|nvidia|cuda|cudnn)($|-)"
    ignore_packages=$(pacman -Qq | grep -E "$pattern" | paste -sd, -)
  fi

  if [[ -n "$ignore_packages" ]]; then
    sudo pacman -Syyu --ignore "$ignore_packages" && paru -Syyu --ignore "$ignore_packages"
  else
    sudo pacman -Syyu && paru -Syyu
  fi
  flatpak update
}

md2pdf() {
  npx prettier "$1" > "/tmp/temp.md"
  pandoc "/tmp/temp.md" -o "${1%.md}.pdf" \
    --pdf-engine=lualatex \
    --template=eisvogel \
    -V mainfont='Maple Mono NF CN' \
    -V monofont='Maple Mono NF CN' \
    -V fontsize=8pt \
    -V header-includes='
\directlua{luaotfload.add_fallback("fb", {"[NotoSans-Regular.ttf]", "[NotoSansMono-Regular.ttf]"})}
\AtBeginDocument{%
  \setmainfont[RawFeature={fallback=fb}]{Maple Mono NF CN}%
  \setmonofont[RawFeature={fallback=fb}]{Maple Mono NF CN}%
}
'
}
