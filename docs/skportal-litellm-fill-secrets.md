# skportal LiteLLM · 填密与冒烟清单

**对外**：`https://skportal.shukun.net/litellm`  
**装机**：`deploy/skportal/`（非敏感已就位后执行本清单）

## 1. skportal `/etc/litellm/litellm.env`

填：

- `LITELLM_MASTER_KEY` / `LITELLM_SALT_KEY`（若已生成可跳过）
- `DATABASE_URL=postgresql://litellm:<密码>@127.0.0.1:5432/litellm`（**本机 Postgres**，非 Docker）
- `OPENAI_API_KEY` / `OPENAI_API_BASE`
- `GENERIC_CLIENT_SECRET`（与 skstudio `LITELLM_OIDC_CLIENT_SECRET` 相同）

发版（本机构建源码镜像）：

```bash
cd litellm && ./deploy/skportal/publish.sh
curl -fsS https://skportal.shukun.net/litellm/health/liveliness
```

## 2. 创建 provisioner Key → skstudio

用 Master 在 LiteLLM 建 Virtual Key `skstudio-llm-provisioner`（仅 key 管理权限）。  
写入 skstudio `/etc/skstudio/skstudio.env`：

```
LITELLM_BASE_URL=https://skportal.shukun.net/litellm
LITELLM_PUBLIC_BASE_URL=https://skportal.shukun.net/litellm
LITELLM_ADMIN_KEY=sk-...
SKSTUDIO_LLM_KEY_SEAL_SECRET=...
LITELLM_OIDC_CLIENT_SECRET=...   # = GENERIC_CLIENT_SECRET
```

## 3. skstudio 发版 / 迁移 / 流水线

- 代码含 LLM 集成；`alembic upgrade` 含 `039_llm_gateway`
- `sudo systemctl enable --now skstudio-llm-pipeline.timer`
- 重启 skstudio 后：**我 › LiteLLM › 立即刷新并检查**，或：

```bash
curl -sS -X POST -H "Authorization: Bearer $GOAL_EXECUTION_SERVICE_TOKEN" \
  http://127.0.0.1:8000/internal/ops/llm-pipeline
```

## 4. 冒烟

| 检查 | 期望 |
|------|------|
| `GET …/litellm/health/liveliness` | 200 |
| Admin UI `…/litellm/ui` + OIDC | 仅 LLM 管理员进得去；**壳内**从「我 › LiteLLM」打开（webview SSO）；系统浏览器走 `sso-resume` / 企微 |
| Usage `…/litellm/ui/usage?tab=models` | 管理员可见；**Location 不得**落到站点根 `/ui/…` |
| 误访 `…/ui/usage/`（无 litellm 前缀） | Nginx **301** → `/litellm/ui/usage/` |
| `GET /api/v1/llm/credentials` | `{ base_url: https://skportal.shukun.net/litellm, api_key, … }` |
| 非管理员 OIDC | 授权阶段 403 |

`SERVER_ROOT_PATH=/litellm` 必填（`publish.sh` 幂等写入）；Nginx **保留** `/litellm` 前缀（勿剥）。只设 root path 却仍剥前缀 → `/ui` 404；只剥前缀不设 root path → 307 到站点根 `/ui` → 404。

## 5. 250 入口

**现网已通**：`https://skportal.shukun.net/` 返回 251 占位文案。  
若日后公网根 通、`/litellm` 独 502 且 251 本机 Proxy 已 up → 查 250；配置片段见 `deploy/skportal/edge-250-snippet.conf.example`。
