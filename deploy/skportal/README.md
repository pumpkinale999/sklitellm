# LiteLLM @ skportal（源码树 + 本机 Postgres）

**对外**：`https://skportal.shukun.net/litellm`  
**Admin UI**：`https://skportal.shukun.net/litellm/ui/`（**必须**带 `/litellm` 前缀）  
**进程**：systemd `litellm` → `/opt/litellm/.venv/bin/litellm`（`127.0.0.1:4000`）  
**数据库**：复用本机 PostgreSQL **`127.0.0.1:5432`**（角色/库 `litellm`）——**不起** Docker DB  

## 路径约定（易踩坑）

| 层 | 行为 |
|----|------|
| 浏览器 | 只访问 `/litellm/...` |
| Nginx | `location /litellm/` **保留前缀**反代到 `127.0.0.1:4000`（`proxy_pass` **无**尾部 URI）；误访 `/ui/` **301** → `/litellm/ui/` |
| LiteLLM | `SERVER_ROOT_PATH=/litellm`：Admin UI / `_next` 挂在 `/litellm/ui`、`/litellm/_next` |

`SERVER_ROOT_PATH` 与「剥前缀」**不能**同开：剥前缀时 `/ui/` 在进程侧 404，浏览器侧深链也会掉到站点根。

## 发版

```bash
./deploy/skportal/publish.sh
```

默认从 **PyPI** 安装与仓版本一致的 `litellm[proxy,extra_proxy]==1.109.1`（带预编译 wheel，免本机编 Rust）。  
`/opt/litellm` 仍保留完整源码树（config / 对照 / 日后可改）。  
`publish.sh` 会幂等写入 `SERVER_ROOT_PATH=/litellm`，并冒烟校验 UI `Location` 含 `/litellm`。

若要 **editable + 改 C/Rust 扩展**：

```bash
# 先在 skportal 装好 rustup，再：
LITELLM_INSTALL_MODE=editable ./deploy/skportal/publish.sh
```

只改 Python 业务逻辑时：可先 PyPI 跑通；深度改 `litellm/` 源码再切 editable。

## 现网状态

- host DB `litellm` 已建  
- `curl …/litellm/health/liveliness` → `"I'm alive!"`  
- Nginx **保留** `/litellm` + `SERVER_ROOT_PATH` + `/ui` 兜底 301  

## 你还要填

`/etc/litellm/litellm.env`：`OPENAI_*`（Master/SALT/DATABASE_URL/OIDC/`SERVER_ROOT_PATH` 由装机/发版处理）
