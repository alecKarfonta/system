# Create zsh config directory if it doesn't exist
if [ ! -d "$HOME/.config/zsh" ]; then
  mkdir -p "$HOME/.config/zsh"
fi

# Download Zinit, if it's not there yet
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Performance optimization - compile zcompdump once a day
autoload -Uz compinit 
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export DOCKER_BUILDKIT=1

# Ubuntu-specific PATH additions
export PATH=$PATH:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Miniconda3 path
if [ -d "$HOME/miniconda3" ]; then
  source ~/miniconda3/bin/activate
fi


export GIT_USERNAME="AlecKarfonta"
# Remove the token for security reasons
export GIT_ACCESS_TOKEN="REMOVED-FOR-SECURITY"

# Load aliases if file exists
if [ -f ~/.alias.sh ]; then
    source ~/.alias.sh
fi

if [ -f ~/.alias ]; then
    source ~/.alias
fi

# Set name of the theme to load
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# Better directory navigation
setopt auto_cd              # Change directory without cd command
setopt auto_pushd           # Push directory to stack on cd
setopt pushd_ignore_dups    # Don't push duplicate directories
setopt pushd_minus          # Invert + and - meaning in pushd

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab
zinit light zsh-users/zsh-history-substring-search
zinit light MichaelAquilina/zsh-you-should-use
zinit light hlissner/zsh-autopair

# Add in snippets
# Needed for loading next git.zsh without errors
zinit snippet OMZL::async_prompt.zsh
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::aliases
zinit snippet OMZP::globalias
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# Load completions
autoload -U +X bashcompinit && bashcompinit
autoload -Uz compinit && compinit

zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region
bindkey '^n' forward-word # auto-accept partial suggestion from zsh-autosuggestion
bindkey '^[[3~' delete-char
bindkey '^[OH' beginning-of-line
bindkey '^[OF' end-of-line
bindkey '\e\e[C' forward-word
bindkey '\e\e[D' backward-word

# History
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
unsetopt EXTENDED_HISTORY
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# All custom functions - only source if files exist
if [ -d "$HOME/.config/zsh" ] && [ "$(ls -A $HOME/.config/zsh/*.zsh 2>/dev/null)" ]; then
  for file in "$HOME"/.config/zsh/*.zsh; do
    source "$file"
  done
fi

# Shell integrations
if [[ -f ~/.fzf.zsh ]]; then
  source ~/.fzf.zsh
fi
# Remove problematic fzf command
# eval "$(fzf --zsh)"
# zi is defined by zinit as alias zi='zinit'. Unalias it to use with zoxide
unalias zi 2>/dev/null || true
eval "$(zoxide init zsh)"
# Remove problematic GitHub Copilot command
# eval "$(gh copilot alias -- zsh)"

# NVM setup - lazy loading for faster startup
export NVM_DIR="$HOME/.nvm"
# Load NVM only when needed
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm "$@"
}
node() {
  unset -f node
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  node "$@"
}
npm() {
  unset -f npm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  npm "$@"
}

# Useful aliases
alias zshconfig="$EDITOR ~/.zshrc"
alias ohmyzsh="$EDITOR ~/.oh-my-zsh"
alias reload="source ~/.zshrc"
alias update="sudo apt update && sudo apt upgrade -y"
alias c="clear"
alias clear="clear"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ls="ls --color=auto"
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"
alias grep="grep --color=auto"
alias ip="ip -color=auto"
alias diff="diff --color=auto"

# Helpful functions
mkcd() { mkdir -p "$1" && cd "$1"; }
extract() {
  if [ -f $1 ]; then
    case $1 in
      *.tar.bz2)   tar xjf $1     ;;
      *.tar.gz)    tar xzf $1     ;;
      *.bz2)       bunzip2 $1     ;;
      *.rar)       unrar e $1     ;;
      *.gz)        gunzip $1      ;;
      *.tar)       tar xf $1      ;;
      *.tbz2)      tar xjf $1     ;;
      *.tgz)       tar xzf $1     ;;
      *.zip)       unzip $1       ;;
      *.Z)         uncompress $1  ;;
      *.7z)        7z x $1        ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}