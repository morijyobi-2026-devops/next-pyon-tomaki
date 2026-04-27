# ===== fzf =====
eval "$(fzf --bash)"
export FZF_DEFAULT_OPTS="--layout=reverse --border --height=40% --history=$HOME/.fzf_history"

# ===== ghq repo 移動 =====
alias repo='cd "$(ghq list -p | fzf)"'

# ===== ファイル検索（VSCode風・履歴付き）=====
f() {
  local file
  local query

  query=$(tail -n 1 ~/.f_history 2>/dev/null)

  file=$( (tac ~/.f_history 2>/dev/null; fdfind . --type f --hidden --exclude .git) | \
    awk '!seen[$0]++' | \
    fzf \
      --query "$query" \
      --preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}') || return

  echo "$file" >> ~/.f_history
  awk '!seen[$0]++' ~/.f_history > ~/.f_history.tmp && mv ~/.f_history.tmp ~/.f_history

  if command -v code >/dev/null 2>&1; then
    code "$file"
  else
    vim "$file"
  fi
}

# ===== ripgrep =====
alias rg='rg --max-count=0'  # すべてのマッチを表示
# コード検索（ripgrep + fzf）
rgs() {
  local query="${1:-.}"
  rg --type-list | head -20 | \
  fzf \
    --multi \
    --preview "rg --type {1} '$query'" \
    --preview-window "right:50%" || return
}
