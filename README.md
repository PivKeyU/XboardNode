# XboardNode User Monitor

XBoard-Node `v1.13-user-monitor.3` 一键安装与升级脚本，适用于 Linux x86_64、
machine 模式和 sing-box 节点。

## 首次安装

```bash
curl -fsSL https://raw.githubusercontent.com/PivKeyU/XboardNode/main/install.sh | \
sudo bash -s -- \
  --mode machine \
  --panel 'https://ovo.pivkeyu.com' \
  --token '替换为该机器的令牌' \
  --machine-id 13
```

每台机器使用其对应的令牌和 `machine-id`。

## 升级现有节点

```bash
curl -fsSL https://raw.githubusercontent.com/PivKeyU/XboardNode/main/install.sh | sudo bash
```

升级时会保留 `/etc/xboard-node/config.yml` 和凭据。脚本会校验节点二进制
SHA256，复用固定提交版本的官方安装器处理 systemd、`xbctl`、备份、健康检查
和失败回滚。

## 检查

```bash
/usr/local/bin/xboard-node -v
xbctl status
```

预期版本：

```text
xboard-node v1.13-user-monitor.3
```

当前发布包只支持 Linux x86_64/amd64。不要把真实令牌提交到仓库、工单或公开聊天。
