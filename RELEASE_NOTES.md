### Bug Fixes

- **Reliable Enhanced Mode Port Resolution** — `clashWriteEnhancedConfig` now promotes any user-configured `port` or `socks-port` into `mixed-port` and only falls back to `7890` when nothing is configured, eliminating the "Ports Open Fail" popup for source configs that omit explicit port fields. (#75)
- **Actionable Port-Open Failure Alert** — The startup error now describes the real cause (mixed-port and port both 0) and embeds the last lines of `~/.config/clashfx/.mihomo_core.log`; the "Edit Config" button opens the active `.enhanced_config.yaml` when Enhanced Mode is on. (#75)
- **Corrected Configuration Path Documentation** — READMEs and the bug report template now reference `~/.config/clashfx` instead of the legacy `~/.config/clash`. (#75)

---
### 修复

- **增强模式端口可靠生成** — `clashWriteEnhancedConfig` 现在会将用户配置的 `port` 或 `socks-port` 自动提升为 `mixed-port`，只有完全未配置时才回退到 `7890`，从根源上消除订阅未显式声明端口字段时的“端口打开失败”弹窗。（#75）
- **更可操作的启动失败提示** — 启动错误弹窗现在描述真实原因（mixed-port 和 port 均为 0），并嵌入 `~/.config/clashfx/.mihomo_core.log` 末尾内容；增强模式下点击“编辑配置”会直接打开当前生效的 `.enhanced_config.yaml`。（#75）
- **配置路径文档更正** — README 与 issue 模板中的配置目录从遗留的 `~/.config/clash` 修正为 `~/.config/clashfx`。（#75）
