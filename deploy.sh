#!/usr/bin/env bash
# ==========================================================================
#  deploy.sh —— 在服务器上执行，把站点更新到 GitHub 上 main 分支的最新状态
#
#  第一次跑会克隆，之后每次跑只是 fetch + reset。
#  静态站改了 HTML/CSS 不需要 reload nginx；只有改了 vhost 才需要。
#
#  用法：
#      sudo /opt/server/www/lingwang/deploy.sh
#      BRANCH=main SITE_DIR=/opt/server/www/lingwang ./deploy.sh
# ==========================================================================

set -Eeuo pipefail

SITE_DIR="${SITE_DIR:-/opt/server/www}"
BRANCH="${BRANCH:-main}"
REPO="${REPO:-https://gitee.com/amz_analysis/lingwang}"

log() { printf '\033[36m[deploy]\033[0m %s\n' "$*"; }
die() { printf '\033[31m[deploy] ERROR\033[0m %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "没装 git：sudo apt-get install -y git"

if [[ ! -d $SITE_DIR/.git ]]; then
    # 防止指错目录时把别的东西当成站点根
    if [[ -d $SITE_DIR ]] && [[ -n "$(ls -A "$SITE_DIR" 2>/dev/null)" ]]; then
        die "$SITE_DIR 非空且不是 git 仓库。
  里面的东西不会被清理，请先备份移走，或用 SITE_DIR 指向别处。"
    fi
    log "首次部署：克隆到 $SITE_DIR"
    mkdir -p "$(dirname "$SITE_DIR")"
    git clone --branch "$BRANCH" "$REPO" "$SITE_DIR"
else
    log "拉取 origin/$BRANCH"

    # 工作区是要发布的产物，不留本地改动；有意外改动时这里会直接丢弃
    if [[ -n "$(git -C "$SITE_DIR" status --porcelain)" ]]; then
        log "工作区有本地改动，按发布目录处理，直接覆盖"
    fi

    git -C "$SITE_DIR" fetch --prune origin "$BRANCH"
    git -C "$SITE_DIR" reset --hard "origin/$BRANCH"
    git -C "$SITE_DIR" clean -fd --quiet
fi

log "当前版本：$(git -C "$SITE_DIR" log -1 --format='%h  %ad  %s' --date=short)"
log "文件数：$(git -C "$SITE_DIR" ls-files | wc -l)"
log "完成（静态站不需要 reload nginx）"
