# 部署

站点在 GitHub：`vibeluvcommerce/lingwang`（public，默认分支 `main`）。
服务器上的更新方式就是 **git pull**，不传文件、不打压缩包。

```
本地改页面 → git commit → git push
                          ↓
            服务器 deploy.sh：fetch + reset
                          ↓
              /opt/server/www/lingwang  ← nginx 的 root
```

## 一、服务器一次性设置

```bash
# 1) 依赖
sudo apt-get update && sudo apt-get install -y git nginx

# 2) 克隆（公开仓库，不需要任何凭据）
sudo git clone https://github.com/vibeluvcommerce/lingwang.git /opt/server/www/lingwang

# 3) 赋可执行权限
sudo chmod +x /opt/server/www/lingwang/deploy.sh
```

nginx 站点配置：

```nginx
server {
    listen 80;
    server_name zhangxinshi.com www.zhangxinshi.com;

    root  /opt/server/www/lingwang;
    index index.html;

    # 仓库目录就是站点根：.git 绝不能被下载，
    # 仓库里的 README / DEPLOY / deploy.sh 也不是给访客看的
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    location ~* \.(md|sh|gitignore|gitattributes)$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
```

改完 `sudo nginx -t && sudo systemctl reload nginx`。

## 二、每次更新

```bash
sudo /opt/server/www/lingwang/deploy.sh
```

输出最后一行是新版本 commit。静态文件即时生效，不需要 reload nginx。

## 三、如果以后改回 private

公开仓库匿名可克隆，不用配凭据。改回 private 后，服务器要在仓库 Settings → Deploy keys 里加一把只读密钥：

```bash
sudo ssh-keygen -t ed25519 -N '' -f /root/.ssh/lingwang_deploy
sudo cat /root/.ssh/lingwang_deploy.pub        # 粘到 Deploy keys（不要勾 Allow write）
sudo git -C /opt/server/www/lingwang remote set-url origin \
     git@github.com:vibeluvcommerce/lingwang.git
```

服务器连不上 `github.com:22` 时，在 `/root/.ssh/config` 里改走 443：

```
Host github.com
    HostName ssh.github.com
    Port 443
    User git
```

## 四、不要提交的东西

`.gitignore` 已拦截 `*.key / *.pem / *.crt / *.zip`。证书私钥（例如阿里云下载的 `zhangxinshi.com.key`）**只放服务器**，用 `scp` 传一次，永远不进 Git —— 仓库现在是公开的，一旦提交就等于公开。
