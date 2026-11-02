# 部署

站点在 GitHub：`vibeluvcommerce/lingwang`（private，默认分支 `main`）。
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

# 2) 克隆（private 仓库，先看下面「认证」一节）
sudo git clone https://github.com/vibeluvcommerce/lingwang.git /opt/server/www/lingwang

# 3) 赋可执行权限
sudo chmod +x /opt/server/www/lingwang/deploy.sh
```

nginx 站点配置里，root 指向这个目录，**并且必须挡掉 `.git`**：

```nginx
server {
    listen 80;
    server_name zhangxinshi.com www.zhangxinshi.com;

    root  /opt/server/www/lingwang;
    index index.html;

    # 关键：仓库目录就是站点根，.git 必须挡住，否则源码和远端配置全暴露
    location ~ /\. {
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

## 三、private 仓库怎么认证

服务器拉私有仓库需要凭据，二选一：

**A. Deploy key（推荐，只读、只对这一个仓库有效）**

在服务器上生成密钥，然后把公钥贴到 GitHub 仓库的 Settings → Deploy keys（不要勾 Allow write）：

```bash
sudo ssh-keygen -t ed25519 -N '' -f /root/.ssh/lingwang_deploy
sudo cat /root/.ssh/lingwang_deploy.pub      # 复制这一行去 GitHub 粘贴

# 配好之后，把 remote 换成 SSH 形式
sudo git -C /opt/server/www/lingwang remote set-url origin \
     git@github.com:vibeluvcommerce/lingwang.git
```

如果服务器连不上 `github.com:22`（国内常见），改用 443 端口：

```bash
# /root/.ssh/config
Host github.com
    HostName ssh.github.com
    Port 443
    User git
```

**B. 把仓库设为 public**

站点本来就是公开的，仓库里也没有任何密钥（见下）。设为 public 后服务器可匿名克隆，上面整节都可以跳过。

## 四、不要提交的东西

`.gitignore` 已经拦住 `*.key / *.pem / *.crt / *.zip`。证书私钥（比如阿里云下载的 `zhangxinshi.com.key`）**只能放服务器**，通过 `scp` 传一次即可，永远不进 Git。
