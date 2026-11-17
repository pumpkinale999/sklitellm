# LiteLLM 按模型用量验收（共识 §8.5）

**范围**：仅验证 LiteLLM Admin UI 的按模型 spend 统计可达；**不做**分项限额；skstudio **不**建第二套账本。

## 前置

- [ ] skstudio OIDC 已配（`docs/skstudio-oidc.env.example`）
- [ ] 操作者满足 `(is_reviewer ∨ litellm_admin_extra) ∧ ¬litellm_admin_deny`
- [ ] `LITELLM_PUBLIC_BASE_URL=https://skportal.shukun.net/litellm`（非 loopback）

## 步骤

1. 以 LLM 管理员登录 skstudio → **我 › 系统管理 › LiteLLM**。
2. 点击 **各模型的使用情况**（深链 `https://skportal.shukun.net/litellm/ui/usage?tab=models`）。
3. 完成 OIDC 后应进入 LiteLLM Usage · models 页签。
4. （可选）用某 Virtual Key 打几条 chat 后刷新，确认模型维度 spend 有数据。
5. 非管理员：直接打开 Admin UI / 深链应在 IdP **授权阶段 403**（不发码）。

## 通过标准

| 项 | 期望 |
|----|------|
| 深链 URL | `…/ui/usage?tab=models` |
| 管理员 | 可见 models 用量 |
| 非管理员 | 无法进入 LiteLLM UI |
| skstudio | 无自建 spend 账本 |

## 手动 curl 备忘

```bash
# 凭证 API（业务面）
curl -sS -H "Authorization: Bearer $SKSTUDIO_JWT" \
  "$SKSTUDIO/api/v1/llm/credentials" -D - | head

# 夜间/手动流水线（机器面）
curl -sS -X POST -H "Authorization: Bearer $GOAL_EXECUTION_SERVICE_TOKEN" \
  "$SKSTUDIO_INTERNAL/internal/ops/llm-pipeline"
```
