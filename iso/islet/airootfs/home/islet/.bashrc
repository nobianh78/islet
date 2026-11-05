# Islet – bash cho lập trình
[[ $- != *i* ]] && return

# lịch sử dài, không trùng, ghi ngay
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=erasedups
shopt -s histappend checkwinsize globstar autocd
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

export EDITOR=nvim VISUAL=nvim
command -v nvim >/dev/null || export EDITOR=nano VISUAL=nano
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"

# công cụ hiện đại (nếu có)
if command -v eza >/dev/null; then
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -l --icons=auto --git --group-directories-first'
    alias la='eza -la --icons=auto --git --group-directories-first'
    alias tree='eza --tree --icons=auto'
fi
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'
alias grep='grep --color=auto'
alias ..='cd ..' ...='cd ../..'
alias g='git' gs='git status -sb' gl='git log --oneline --graph --decorate -20' gd='git diff'
alias code='code-oss'

command -v zoxide >/dev/null && eval "$(zoxide init bash --cmd cd)"     # "cd tên" nhảy tới thư mục hay dùng
[ -f /usr/share/fzf/key-bindings.bash ] && . /usr/share/fzf/key-bindings.bash   # Ctrl+R tìm lịch sử, Ctrl+T tìm tệp
[ -f /usr/share/fzf/completion.bash ] && . /usr/share/fzf/completion.bash
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border=rounded --color=bg+:#1A1A2A,fg+:#FFFFFF,hl:#8B7CFF,hl+:#FF6B97,pointer:#FF6B97,prompt:#8B7CFF,info:#5EEAD4'

command -v starship >/dev/null && eval "$(starship init bash)"
