# 部署

| 项 | 值 |
|---|---|
| 域名 | `zhangxinshi.com`（`www` 301 到主域，`http` 301 到 `https`） |
| 服务器 | Ubuntu，`47.107.228.15` |
| 站点根 | `/opt/server/www`（就是 git 工作区） |
| 证书 | `/etc/nginx/cert/zhangxinshi.com.pem` + `.key`（阿里云，90 天） |
| 仓库 | `vibeluvcommerce/lingwang`（public，`main`） |

```
本地改页面 → git push
                ↓
      服务器 deploy.sh：fetch + reset --hard
                ↓
        /opt/server/www  ← nginx 的 root，静态文件即时生效
```

## 一、首次安装

**1) 把证书传上去**（本地执行）

```bash
scp 28240572_zhangxinshi.com_nginx.zip root@47.107.228.15:/tmp/
```

（服务器上）

```bash
sudo mkdir -p /etc/nginx/cert
sudo unzip -o /tmp/28240572_zhangxinshi.com_nginx.zip -d /etc/nginx/cert
```

**2) 拉代码并安装**

```bash
sudo apt-get install -y git
sudo git clone https://github.com/vibeluvcommerce/lingwang /opt/server/www
sudo chmod +x /opt/server/www/install.sh
sudo /opt/server/www/install.sh
```

`install.sh` 会装 nginx、校验证书与私钥是否配对、渲染 vhost、`nginx -t` 通过后 reload，最后用 `Host: zhangxinshi.com` 对 `https://127.0.0.1/` 自检一次并打印状态码（200 即成功）。

## 二、之后每次更新

```bash
sudo /opt/server/www/deploy.sh
```

只改 HTML/CSS/JS，**不需要 reload nginx**——站点根没变，文件换了就生效。

## 三、证书续期

阿里云这张是 90 天有效（2027-01-30 到期）。到期前重新下载，覆盖同一路径即可：

```bash
sudo unzip -o /tmp/新证书.zip -d /etc/nginx/cert
sudo chmod 600 /etc/nginx/cert/zhangxinshi.com.key
sudo nginx -t && sudo systemctl reload nginx
```

`install.sh` 里已做模数比对，传错文件时会直接报「证书与私钥不匹配」，不会等到 nginx 起不来才发现。

## 四、vhost 说明

模板在 `nginx/zhangxinshi.com.conf`，由 `install.sh` 替换占位符后装到 `/etc/nginx/sites-available/`。改了模板要重新跑一次 `install.sh`。

几个关键点：

- **站点根就是仓库**，所以 `.git` 必须挡住，否则 `/.git/config` 能被直接下载。同理 `README.md`、`DEPLOY.md`、`deploy.sh`、`nginx/*.conf` 都加了 deny 规则。
- **CSS/JS 只缓存 1 小时**：文件名不带内容指纹，给长了会出现「样式改了但没生效」。
- **没开 HSTS**：证书 90 天手动续，先不锁死 https。续期稳定后再打开模板里那行注释即可。
- `http2` 用的是 `listen 443 ssl http2` 写法，兼容 Ubuntu 20.04 自带的 nginx 1.18。

## 五、不要提交的东西

`.gitignore` 已拦截 `*.key / *.pem / *.crt / *.zip`。**仓库是公开的**，证书私钥一旦提交就等于公开泄露——它只在 `/etc/nginx/cert/` 里存在一份。
