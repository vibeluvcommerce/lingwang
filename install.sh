#!/usr/bin/env bash
# ==========================================================================
#  install.sh —— 服务器一次性安装（Ubuntu 20.04+），幂等，可重复执行
#
#  前提：证书已经放到 /etc/nginx/cert/
#        zhangxinshi.com.pem（完整链）
#        zhangxinshi.com.key
#
#  做五件事：
#    1. 装 git / nginx
#    2. 校验证书文件与私钥配对
#    3. 把仓库克隆到 /opt/server/www（站点根就是仓库）
#    4. 渲染 vhost 到 /etc/nginx/sites-available，启用
#    5. nginx -t 通过后 reload
#
#  用法：sudo ./install.sh
# ==========================================================================

set -Eeuo pipefail

DOMAIN="${DOMAIN:-zhangxinshi.com}"
SITE_DIR="${SITE_DIR:-/opt/server/www}"
REPO="${REPO:-https://github.com/vibeluvcommerce/lingwang}"
BRANCH="${BRANCH:-main}"
CERT_DIR="${CERT_DIR:-/etc/nginx/cert}"
CERT_CRT="${CERT_CRT:-$CERT_DIR/$DOMAIN.pem}"
CERT_KEY="${CERT_KEY:-$CERT_DIR/$DOMAIN.key}"

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/nginx/$DOMAIN.conf"

LIVE_CONF="/etc/nginx/sites-available/$DOMAIN.conf"
ENABLED_CONF="/etc/nginx/sites-enabled/$DOMAIN.conf"

log()  { printf '\033[36m[install]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[install] WARN\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m[install] ERROR\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "请用 root 运行：sudo $0"

# ==========================================================================
# 1. 依赖
# ==========================================================================
export DEBIAN_FRONTEND=noninteractive
log "系统：$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}")"

for p in git nginx openssl; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || {
        log "安装 $p"
        apt-get update -qq
        apt-get install -y -qq git nginx openssl
        break
    }
done

systemctl enable --now nginx >/dev/null 2>&1 || true

# ==========================================================================
# 2. 证书
# ==========================================================================
[[ -f $CERT_CRT ]] || die "缺少证书 $CERT_CRT
  把阿里云下载的 pem / key 传上来：
    sudo mkdir -p $CERT_DIR
    # 本地执行：scp 28240572_${DOMAIN}_nginx.zip root@<ip>:/tmp/
    sudo unzip -o /tmp/28240572_${DOMAIN}_nginx.zip -d $CERT_DIR"
[[ -f $CERT_KEY ]] || die "缺少私钥 $CERT_KEY"

chown root:root "$CERT_CRT" "$CERT_KEY"
chmod 644 "$CERT_CRT"
chmod 600 "$CERT_KEY"

log "证书：$DOMAIN"
openssl x509 -in "$CERT_CRT" -noout -enddate 2>/dev/null | sed 's/^/          /' || true
openssl x509 -in "$CERT_CRT" -noout -ext subjectAltName 2>/dev/null | sed 's/^/          /' || true

# 私钥必须和证书配对，否则 nginx 起不来（错配时报错信息很难懂，这里先挡）
CRT_MOD="$(openssl x509 -in "$CERT_CRT" -noout -modulus 2>/dev/null || true)"
KEY_MOD="$(openssl rsa  -in "$CERT_KEY" -noout -modulus 2>/dev/null || true)"
if [[ -n $CRT_MOD && -n $KEY_MOD && $CRT_MOD != "$KEY_MOD" ]]; then
    die "证书与私钥不匹配（modulus 不一致），检查是否传错文件"
fi

# ==========================================================================
# 3. 克隆仓库到站点根
# ==========================================================================
if [[ -d $SITE_DIR/.git ]]; then
    log "已是 git 仓库，跳过克隆（更新用 $SITE_DIR/deploy.sh）"
else
    if [[ -d $SITE_DIR ]] && [[ -n "$(ls -A "$SITE_DIR" 2>/dev/null)" ]]; then
        die "$SITE_DIR 非空且不是 git 仓库。
  里面的东西不会被自动清理，请先备份后移走，或改 SITE_DIR 指向别处。"
    fi
    mkdir -p "$(dirname "$SITE_DIR")"
    log "克隆 $REPO -> $SITE_DIR"
    git clone --branch "$BRANCH" --quiet "$REPO" "$SITE_DIR"
fi

chmod +x "$SITE_DIR/deploy.sh" 2>/dev/null || true
[[ -f $TEMPLATE ]] || die "找不到 vhost 模板 $TEMPLATE"

# ==========================================================================
# 4. 安装 vhost
# ==========================================================================
render() {
    sed -e "s|__DOMAIN__|$DOMAIN|g" \
        -e "s|__SITE_DIR__|$SITE_DIR|g" \
        -e "s|__CERT_CRT__|$CERT_CRT|g" \
        -e "s|__CERT_KEY__|$CERT_KEY|g" \
        "$TEMPLATE"
}

mkdir -p /var/www/certbot
render > /tmp/"$DOMAIN".conf.new

if [[ -f $LIVE_CONF ]] && cmp -s /tmp/"$DOMAIN".conf.new "$LIVE_CONF"; then
    log "vhost 无变化"
else
    [[ -f $LIVE_CONF ]] && cp -a "$LIVE_CONF" "$LIVE_CONF.bak.$(date +%Y%m%d-%H%M%S)"
    install -m 0644 /tmp/"$DOMAIN".conf.new "$LIVE_CONF"
    ok "已写入 $LIVE_CONF"
fi
ln -sfn "$LIVE_CONF" "$ENABLED_CONF"

if [[ -e /etc/nginx/sites-enabled/default ]]; then
    rm -f /etc/nginx/sites-enabled/default
    log "移除 nginx 默认站点"
fi

# ==========================================================================
# 5. 校验并生效
# ==========================================================================
log "nginx -t"
nginx -t || die "配置校验失败，旧配置已备份为 .bak.*，修好后重跑"

systemctl reload nginx
ok "nginx 已重载"

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow 'Nginx Full' >/dev/null 2>&1 || true
    log "ufw 放行 80/443"
fi

# ==========================================================================
# 6. 自检
# ==========================================================================
CODE="$(curl -sS -o /dev/null -w '%{http_code}' -k -H "Host: $DOMAIN" https://127.0.0.1/ 2>/dev/null || true)"
cat <<EOF

────────────────────────────────────────────────────────────────
 安装完成
────────────────────────────────────────────────────────────────
 域名      $DOMAIN（www 自动跳主域，80 自动跳 443）
 站点根    $SITE_DIR
 vhost     $LIVE_CONF
 证书      $CERT_CRT
 私钥      $CERT_KEY（600）

 本机 https 自检：HTTP $CODE
 更新站点：sudo $SITE_DIR/deploy.sh
 续期证书：覆盖 $CERT_DIR 下两个文件后 sudo systemctl reload nginx
────────────────────────────────────────────────────────────────
EOF
