# LiteLLM × skstudio 集成共识

**用途**：钉死 LiteLLM（AI Gateway）与 skstudio（身份与编排）的分工、登录、Virtual Key、计量与落地顺序。  
**版本**：v0.6.2（2026-11-17）  
**状态**：共识已拍 · **§8 已按步落地** · 评价 **A** · **拓扑：LiteLLM@skportal 子路径 `/litellm`（跨机）**  
**对外基址**：`https://skportal.shukun.net/litellm` · 装机：`deploy/skportal/`  
**仓**：本文件在 `sklitellm` / `litellm` 仓 `docs/`；实现横切 skstudio + 本仓 Mac 本地 Proxy。  
**skstudio env 样例**：`skstudio/backend/.env.example`（`LITELLM_*` / `SKSTUDIO_LLM_KEY_SEAL_SECRET` / `LITELLM_OIDC_CLIENT_SECRET`）。  
**UI 线框**：Cursor canvas `skstudio-me-system-admin-ui.canvas.tsx`（「我 › 系统管理」；真源以本节 §2.3 / §2.4 为准）。  
**OIDC 样例**：`docs/skstudio-oidc.env.example`。  
**用量验收**：`docs/usage-models-acceptance.md`。

---

## 0. 一句话

> skstudio 管身份、权限门、缺省套餐与 Key 生命周期；LiteLLM 管网关、限额执行与计量。人进管理台走 **仅绑定 LiteLLM 的 OIDC**；业务调模型走 **Virtual Key**（经 skstudio 凭证 API 领取后直连 LiteLLM）。

---

## 1. 分工

| 职责 | 归属 |
|------|------|
| 身份、LLM 管理员判定、企微花名册 | **skstudio** |
| **缺省套餐**（tier0）配置、Key 创建/禁用/90 天轮换编排、密文保管、凭证查询 API | **skstudio** |
| 模型路由、请求限额执行、spend/log、**个人/Key 级**管理与统计 UI | **LiteLLM** |
| 完整管理台 UI | **LiteLLM 自带**；skstudio **不**重做 Key 编辑器 |

### 1.1 两层配置（已拍）

| 设什么 | 在哪设 |
|--------|--------|
| **全员缺省套餐**（模型名单、`$5`/30d、RPM 等） | skstudio「系统管理 → LiteLLM」**缺省策略**（供夜间发 Key） |
| **某人/某 Key** 的模型、预算、速率、用量/按模型统计 | **LiteLLM Admin UI**（skstudio 只做入口跳转） |

个人在 LiteLLM UI 改过的 Key 打 `metadata.skstudio_policy=custom`，夜间任务 **不覆盖**。

---

## 2. 管理面（人）

### 2.1 登录（OIDC 最小契约）

- Admin UI：**skstudio OIDC SSO**。
- **范围锁死**：仅服务 LiteLLM Admin UI；不做万能未来 SSO。
- Client 固定：`litellm-admin-ui`；redirect 仅 LiteLLM 的 `/sso/callback`（完整 URL 随部署主机名）。
- `sub` = skstudio `uid`（稳定、不可变）。
- claim：`litellm_admin: boolean`（由 §2.2 规则算出）。
- 非 admin：优先在 **IdP 授权阶段拒绝**（不发码）。
- 普通人：**不能**登录 LiteLLM UI。

### 2.2 角色

- skstudio 设 **LiteLLM 系统管理员**。
- **评审员默认具备** LLM 管理员资格；须可剔/可加：`(is_reviewer ∨ litellm_admin_extra) ∧ ¬litellm_admin_deny`（系统管理内名单/勾选）。
- OIDC 携带 `litellm_admin`；非 admin 拒入 UI。

### 2.3 skstudio「我 › 系统管理」UI 共识（已拍）

对齐「我」Tab **既有 section 模式**（与「工具」「系统使用和反馈」同构）：

1. 「我」首页出现分区标题 **系统管理**。  
2. 分区下 **仅两行 CTA**（无枢纽页、不在列表页摊开表单）：  
   - **企微同步**（仅评审员可见）  
   - **LiteLLM**（仅 LLM 管理员可见）  
3. 点击 CTA → **进入各自子页**；子页提供 **返回**（回「我」首页 / 系统管理锚点）。  
4. **禁止**：单独「系统管理枢纽」中间页；禁止把 LiteLLM 全表单嵌在「我」首页。  
5. 产品文案 **不要**堆解释性权限角标 / 公式说明（权限靠显隐，不靠标签教育）。

#### 路由（示意）

| 路径 | 页 |
|------|-----|
| `/me` | 含「系统管理」section + 两 CTA（已钉） |
| `/me/system/wecom` | 企微同步子页（已钉） |
| `/me/system/litellm` | LiteLLM 管理子页（已钉） |

#### 线框

- Canvas：`skstudio-me-system-admin-ui.canvas.tsx`（工作区 canvases；对照用）。  
- 实现以本节为准；线框与本文冲突时 **以本文为准**。

### 2.4 子页内容

#### 企微同步（`/me/system/wecom`）

- 与 **组织 › 结构 › 同步企微** 同一能力（可镜像入口）。  
- 操作：同步；展示最近一次结果摘要。

#### LiteLLM（`/me/system/litellm`）

| 区块 | 内容 |
|------|------|
| 顶栏 | 返回 · 标题 LiteLLM · **打开 Admin UI**（`LITELLM_PUBLIC_BASE_URL`） |
| 用量入口 | 两行 CTA 深链（见 §3.2）：所有人的使用情况 · 各模型的使用情况 |
| 立即刷新并检查 | 触发 §5.0 同一流水线；展示上次结果摘要；单飞 |
| 缺省套餐 | 编辑/保存 `tier0_default`（模型、`$5`/`30d`、RPM 等；见 §4） |
| 管理员名单 | `litellm_admin_extra` / `litellm_admin_deny` |

**不在本页做**：完整 Key 编辑、按人改预算、重做 Usage 图表（一律 LiteLLM Admin UI）。

---

## 3. 使用面（业务 / Agent）

### 3.1 Virtual Key

- 普通人只用 **Virtual Key** 调 LiteLLM。
- **策略在人，执行在 Key**；可选用户总预算托底。
- **超限**：**429 / budget exceeded**；**禁止**用轮换洗额度。

### 3.2 按模型统计 / 分项限额

| 项 | 状态 |
|----|------|
| 各模型用量/花费统计 | **本期做**；**仅 LiteLLM 管理员** |
| 各模型分项预算上限 | **暂缓** |

计量真源在 LiteLLM；skstudio 不做第二套计费账本。

skstudio「我 › 系统管理 › LiteLLM」提供两个 **Usage 深链**（前缀为 `LITELLM_PUBLIC_BASE_URL`）：

| CTA | URL |
|-----|-----|
| 所有人的使用情况 | `{PUBLIC}/ui/usage?tab=users` |
| 各模型的使用情况 | `{PUBLIC}/ui/usage?tab=models` |

（须已 SSO 为 LLM 管理员；无权限进不了 LiteLLM UI。）

### 3.3 凭证 API

- `GET /api/v1/llm/credentials`（已钉）：鉴权 = 当前工作台用户；返回 `{ base_url, api_key, key_id, rotates_at? }`。
- **禁止**代取他人 Key；服务账号用独立 `user_id=service:…` Key。
- `Cache-Control: no-store`；客户端内存持有；401/轮换后重拉。
- 业务领取后 **直连 LiteLLM**；skstudio **不**代理每条 chat。
- 禁止返回 Master Key、管理用 Key。
- **`base_url`（硬）**：必须是 **skdev / skfde / Desktop 等客户端能访问** 的网关基址（通常为同机 Nginx 反代后的 **HTTPS 公网或内网主机名**，如 `https://<host>/…` 或独立子域）。  
  - **禁止**把 `http://127.0.0.1:4000` 作为凭证 API 的默认返回值——调用方往往不是 skstudio 本机进程，loopback 会打到用户自己的电脑。  
  - `127.0.0.1:4000` 仅用于 **同机服务端**（skstudio 管理任务、本机 BFF 出站）配置 `LITELLM_BASE_URL`（机器侧）。  
  - 凭证 API 返回值来自 skstudio 配置项（如 `LITELLM_PUBLIC_BASE_URL`），与机器侧 `LITELLM_BASE_URL` **可以不同**。

### 3.4 Key 密文

- 明文仅在 generate/regenerate 时出现；**skstudio 服务端保管**（KMS/密封）。
- 日志只记 hash/alias；禁止前端长期存明文。

---

## 4. 缺省套餐 `tier0_default`（已拍）

| 项 | 值 |
|----|-----|
| 套餐 id | `tier0_default` |
| 模型（展示名） | **DeepSeek flash**、**DeepSeek pro** |
| 模型（LiteLLM id） | **`my-gw/deepseek-v4.1-flash`**、**`my-gw/deepseek-v4-pro`**（不用带日期后缀的快照 id）；**禁止** `*` |
| 月预算 | **`max_budget=5` USD**，`budget_duration=30d` |
| 产品口径 | 约 ¥30/月档；内部汇率备忘 **6.7**（闸门以 USD 为准） |
| RPM | **`rpm_limit=60`** |
| TPM | 实现时按上述两模型上下文补一档写入常量表（不挡第一刀） |
| `metadata` | `skstudio_policy=tier0`（默认）；UI 改后 → `custom` |

> LiteLLM 运行时预算/spend **只认 USD**；不可把 `max_budget` 直接填人民币数字。

---

## 5. Key 生命周期（skstudio 编排）

### 5.0 定时与流水线（已拍）

**时区**：`Asia/Shanghai`。  
**自动**：每天 **02:30** 跑同一条流水线（与凌晨业务低谷对齐；避开 00:00 整点与其它任务扎堆）。

流水线顺序（不可颠倒）：

1. **企微通讯录同步**（花名册 / 在职离职真源）  
2. **LiteLLM Key 对齐**：在职补 `tier0` Key；离职 disable；到期 **90 天轮换**（错峰仍按 uid hash，但触发扫描在本任务内）  
3. **健康检查**：LiteLLM `liveliness`（或等价）失败则标记本次失败并告警，**不**静默当成功  

**单飞**：同时只允许一个流水线实例；自动与手动互斥，busy 时手动返回「已在运行」。

### 5.1 对齐规则

| 条件 | 动作 |
|------|------|
| 在职且无 Key | 按 `tier0_default` 创建 Virtual Key |
| 已离职仍有 Key | **disable / block**（默认不 delete，保留 spend 审计） |
| `skstudio_policy=custom` | **不覆盖** |
| delete | 仅合规工单 / 管理员显式抹除 |

### 5.2 90 天轮换

- 由 **skstudio** 调 Management API（不依赖 Enterprise 自动轮换）。
- **宽限期 24h** 双 Key；额度/账本跟人走。
- 按 `uid` hash **错峰**（在扫描窗口内分散 regenerate），避免整点全员同时失效。
- 泄漏可即时吊销（无宽限）。

### 5.3 手动触发（LiteLLM 管理）

- 位置：skstudio「系统管理 → LiteLLM」。
- 按钮：**立即刷新并检查**（文案可微调）。
- 权限：**LLM 管理员**（含自动授的评审员）。
- 行为：与 §5.0 **同一流水线**（企微同步 → Key 对齐 → 健康检查）；返回/展示最近一次：开始/结束时间、成功失败、补 Key / disable / 轮换计数、错误摘要。
- 既有「组织 → 企微同步」手工入口可保留；LiteLLM 管理的手动按钮是 **带 Key 对齐的完整链**，避免只同步花名册却忘了网关。

---

## 6. 部署拓扑（已拍 · v0.6.2 修订）

- **LiteLLM 部署在 skportal（`10.20.19.251`）**；**skstudio 在另一台**（跨机）。原「同机」假设作废。
- **对外基址（钉死）**：`https://skportal.shukun.net/litellm`（子路径；站点根留给未来门户）。
- 入口：`skportal.shukun.net` → **250** TLS（`*.shukun.net`）→ **251** Nginx → `location /litellm/` **保留前缀** → `127.0.0.1:4000/litellm/...`。
- **子路径 UI**：LiteLLM `SERVER_ROOT_PATH=/litellm`（与 Nginx **保留前缀**配套；**禁止**再剥 `/litellm`）；误访站点根 `/ui/` 由 Nginx **301** 到 `/litellm/ui/`。
- skportal 上 LiteLLM 听 **本机 `127.0.0.1:4000`**；**不对公网裸露 4000**；**不**使用 `skportal.shukun.net:4000`。
- 装机资产：`deploy/skportal/`（**PyPI venv + systemd + nginx**；**复用本机 Postgres** `127.0.0.1:5432`，不起 DB 容器）。  
- 发版：笔记本 `./deploy/skportal/publish.sh`（rsync `/opt/litellm` → PyPI/editable → restart + UI Location 冒烟）。
- 配置拆分：  
  - `LITELLM_BASE_URL`＝`https://skportal.shukun.net/litellm`（skstudio 出站；**禁止** skstudio 本机 loopback）  
  - `LITELLM_PUBLIC_BASE_URL`＝同上（凭证 API / Usage / Admin 深链）  
- OIDC：浏览器访问 **skstudio**；LiteLLM Generic OIDC 指向 skstudio 公网（如 `https://skbizmgmt.shukun.net/api/v1/oidc/litellm/*`）。  
- 网络：浏览器/客户端 → PUBLIC；skstudio → BASE；浏览器 → skstudio（登录与 OIDC）。

---

## 7. 机器凭证（skstudio → LiteLLM）

| 谁 | 怎么鉴权 |
|----|----------|
| 人（管理员浏览器） | OIDC SSO |
| skstudio 定时任务 / 编排 | **仅管理用 Virtual Key** `skstudio-llm-provisioner` |

- 配置写入 **skstudio 服务端 env**（勿进前端、勿进「我 › LiteLLM」表单）：

| 变量 | 用途 |
|------|------|
| `LITELLM_BASE_URL` | `https://skportal.shukun.net/litellm`（Management API；禁 skstudio loopback） |
| `LITELLM_ADMIN_KEY` | 管理用 Virtual Key（`skstudio-llm-provisioner`）；**不是** Master Key |
| `LITELLM_PUBLIC_BASE_URL` | 同 BASE（凭证 / Usage / Admin 深链） |

- **禁止**把 Master Key 配给 `LITELLM_ADMIN_KEY`。
- 权限尽量仅 key/user 管理：generate / update / regenerate / block / list 等。
- 样例见 `skstudio/backend/.env.example`。

---

## 8. 落地顺序（硬）

1. ~~管理 Key + Key 保管 + **凭证查询 API**~~ **已交付**（`GET /api/v1/llm/credentials`；Fernet 密封；`llm_user_keys`）  
2. ~~`tier0_default` + **02:30 流水线** + 手动「立即刷新并检查」~~ **已交付**（`POST /api/v1/llm/pipeline/run`；timer `skstudio-llm-pipeline.*`；`/internal/ops/llm-pipeline`）  
3. ~~LiteLLM 专用 OIDC + 仅 admin 进 UI + **「我 › 系统管理」section CTA / 子页**~~ **已交付**（`/api/v1/oidc/litellm/*`；`/me/system/wecom|litellm`）  
4. ~~90 天轮换（24h 宽限 + 错峰，挂在流水线内）~~ **已交付**（流水线内 regenerate + grace；`expire_grace_keys`）  
5. ~~按模型 spend 统计验收~~ **验收清单已交付**（`docs/usage-models-acceptance.md`）；分项限额仍暂缓  

---

## 9. 非目标

- 不改工作台短码主路径去迁就 LiteLLM。  
- GitLab 仍是 **skdev** 的事，与本集成独立。  
- 本机开发可用 Master Key；生产不以 env 口令当长期唯一管理员方案。  
- skstudio 不建成通用 IdP「一次做完所有未来 SSO」。  
- skstudio 不重做完整 LiteLLM Key/Usage 管理台。

---

## 10. 评价摘要

| 维度 | 级 |
|------|-----|
| 身份主权 / 权限模型 / 机器凭证 | **A** |
| Key 生命周期 / 套餐与拓扑 | **A**（模型 id / $5 / RPM / 02:30 / base_url 已钉） |
| 可测试性 | **B+** |
| **总评** | **A（§8 已落地）** |

实现落点：skstudio `backend/app/services/llm_*`、`routes_llm` / `routes_litellm_oidc`；前端 `MeSystemAdminSection` + `/me/system/*`；deploy `skstudio-llm-pipeline.{timer,service,sh}`。

---

## 11. 修订

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.6.3 | 2026-11-17 | §6：`SERVER_ROOT_PATH=/litellm` + Nginx `/ui`→`/litellm/ui` 兜底；修 Admin UI 307 到站点根 404 |
| v0.6.2 | 2026-11-17 | §6：对外钉死 `https://skportal.shukun.net/litellm`；`deploy/skportal/` 装机 |
| v0.6.1 | 2026-11-17 | §6/§7：**LiteLLM@skportal 跨机**；`LITELLM_BASE_URL` 禁止 skstudio 本机 loopback |
| v0.6.0 | 2026-11-17 | §8 五步实现交付：凭证 API、流水线、OIDC+系统管理 UI、90d 轮换、用量验收清单；路由钉死 `/me/system/*` |
| v0.5.0 | 2026-11-17 | §2.3/§2.4：**我 › 系统管理** UI 共识（section 两 CTA → 子页 → 返回；无枢纽）；线框 canvas；LiteLLM 子页区块表 |
| v0.4.3 | 2026-11-17 | 钉死 env：`LITELLM_BASE_URL` / `LITELLM_ADMIN_KEY` / `LITELLM_PUBLIC_BASE_URL`；写入 skstudio `backend/.env.example` |
| v0.4.2 | 2026-11-17 | LiteLLM 管理页两深链：`/ui/usage?tab=users` · `tab=models`；UI section CTA 进子页 |
| v0.4.1 | 2026-11-17 | 凭证 `base_url`＝**客户端可达**的 `LITELLM_PUBLIC_BASE_URL`；禁止默认 `127.0.0.1`；与机器侧 `LITELLM_BASE_URL` 拆分 |
| v0.4.0 | 2026-11-17 | tier0 id：`my-gw/deepseek-v4.1-flash` + `my-gw/deepseek-v4-pro`；`rpm_limit=60`；总评升 **A** |
| v0.3.0 | 2026-11-17 | 每天 02:30；流水线；手动立即刷新并检查；单飞 |
| v0.2.0 | 2026-11-17 | tier0 金额/拓扑/OIDC/凭证/两层配置等 |
| v0.1.0 | 2026-11-17 | 首版 |
