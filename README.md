# redotpay-payment

让 **AI Agent**（Cursor、Claude Code、Claude Desktop、Windsurf、Codex、Cline 等）代你完成 **MPP 402 协议支付**——访问付费 API、按量计费的推理服务等，无需自己写支付代码。

本仓库提供预编译安装包与一键安装脚本。

## 适用场景

- Agent 调用返回 `402 Payment Required` 的 API
- 希望由 Agent 自动处理授权、选支付方式并完成代付
- 已在 RedotPay App 中拥有账户与支付能力

## 安装

**一条命令即可**（无需参数）：

```sh
curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh | sh
```

想先查看脚本再执行：

```sh
curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh -o install.sh
less install.sh
sh install.sh
```

安装器会自动：

1. 下载与你系统匹配的最新版本（macOS / Linux，自动识别芯片架构）
2. 将 `redotpay-payment` 安装到 `~/.local/bin`（若 `/usr/local/bin` 可写则优先使用）
3. 在常用 Agent 宿主中注册 MCP 服务 `redotpay-payment`
4. 安装 Agent 使用的 skill 说明（Cursor、Claude、Codex、Cline 等全局目录）

**前置依赖**：系统需已安装 [`jq`](https://jqlang.org/)（macOS：`brew install jq`）。

## 安装后

1. **重启**你正在使用的 Agent 应用（Cursor / Claude Code / Claude Desktop 等），以加载 MCP。
2. 在对话中让 Agent 访问需要代付的 API；首次使用若需授权，Agent 会展示 **二维码**，用 **RedotPay App** 扫码确认即可。
3. 同一台设备上授权成功后，后续代付通常**无需每笔都扫码**。

## 支持的 Agent

| Agent | MCP 配置 | Skill |
|-------|----------|-------|
| Cursor | 全局 `~/.cursor/mcp.json` | `~/.cursor/skills/redotpay-payment/` |
| Claude Code | `~/.claude.json` | `~/.claude/skills/redotpay-payment/` |
| Claude Desktop | macOS 应用配置 | — |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` | — |
| Codex CLI | — | `~/.agents/skills/redotpay-payment/` |
| Cline | 需在 IDE 设置中手动添加 MCP | `~/.cline/skills/redotpay-payment/` |

## 卸载

```sh
curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh | sh -s -- --uninstall
```

## 常见问题

**安装后 Agent 找不到 MCP？**  
重启 IDE / 客户端；在 MCP 设置中确认已启用 `redotpay-payment`。

**提示找不到 `jq`？**  
先安装 jq，再重新运行安装命令。

**macOS 钥匙串反复弹窗？**  
对正在使用的 `~/.local/bin/redotpay-payment` 选择「始终允许」。安装器使用固定路径，升级后一般不必重复授权。

**Windows？**  
当前一键安装脚本面向 macOS / Linux。Windows 可从 [Releases](https://github.com/redotpay/redotpay-payment-skill/releases) 下载 `windows_x86_64.zip`，解压后在 Agent 的 MCP 设置中手动配置可执行文件路径。

## 关于本仓库

- 仅含安装脚本与发布产物
- 生产环境对接 RedotPay API：`https://apiv2.redotpay.com`
- 问题反馈请通过 RedotPay 官方支持渠道
