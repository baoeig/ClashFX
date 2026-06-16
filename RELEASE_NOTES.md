### Bug Fixes

- **Menu Bar Status Item Uses Less Space** — The upload/download speed indicator now sizes the macOS menu bar item from the actual rendered speed text instead of reserving a wide fixed block, keeping ClashFX compact in crowded menu bars while still expanding when longer speeds need room. (#127)
- **Enhanced Mode Toggle No Longer Rebuilds the Menu Immediately** — After enabling or disabling Enhanced Mode, ClashFX now coalesces and slightly delays the config/stream/proxy-menu refresh work so quickly reopening the menu does not visibly freeze or flash during the toggle completion. (#125)

### Contributors

- @qzxwj — Reported the menu bar status item occupying too much width (#127)
- @ljssafe — Reported the post-toggle Enhanced Mode menu freeze/flash (#125)

---

### 修复

- **菜单栏状态项更省空间** — 上传 / 下载速度显示现在会根据实际渲染出来的文字宽度调整菜单栏项，不再预留过宽的固定区域；菜单栏拥挤时更紧凑，速度文字变长时也仍会自动扩展。(#127)
- **增强模式切换后不再立刻重建菜单** — 开启或关闭增强模式后，ClashFX 现在会合并并稍微延迟配置同步、stream 重置和代理菜单刷新，避免用户马上重新打开菜单时出现明显卡顿或闪一下。(#125)

### 贡献者

- @qzxwj — 反馈菜单栏状态项占用宽度偏大的问题 (#127)
- @ljssafe — 反馈增强模式切换后菜单快速打开会卡顿 / 闪一下的问题 (#125)

<!-- Previous release notes -->

---

### Bug Fixes

- **Enhanced Mode Now Respects Your `tun.stack` Setting** — The generated `.enhanced_config.yaml` previously hardcoded `stack: mixed`, silently overriding a user-configured `tun.stack`. If your config set `system` (or `gvisor`), the dashboard showed `mixed` and reverting it never stuck. ClashFX now reads `tun.stack` from your source config, validates it against `system`/`gvisor`/`mixed` (case-insensitive), and only falls back to `mixed` when it is unset or invalid. Both the embedded and external core paths use the same resolved value so they never diverge. (#115)
- **Dashboard Theme & Column Settings Now Persist** — In Enhanced Mode the external controller was assigned a random port on every launch, so the Yacd dashboard origin (`127.0.0.1:PORT`) changed each time and its per-origin `localStorage` (theme, custom columns) appeared to reset. ClashFX now pins a stable controller port (`19090`) and only falls back to a random free port if that port is already taken, keeping the dashboard origin — and your saved preferences — stable across launches. (#115)
- **Enhanced Mode Startup Is More Resilient** — Enabling Enhanced Mode now automatically retries once when the external core fails to bind (e.g. a transient port race or a leftover `mihomo_core` process holding the controller port). Each retry regenerates the config with a fresh port instead of failing outright, so toggling Enhanced Mode on is far less likely to error out and require a manual retry.
- **Reopening ClashFX Reveals the Menu Bar Icon** — When ClashFX is already running and you launch it again from Finder, Spotlight, Launchpad, or the Dock, it now pops open the menu bar menu so you can locate the icon — helpful when the menu bar is crowded and the icon is hidden. Thanks @hangox for the suggestion. (#114)

### Contributors

- @hangox — Suggestion to reveal the menu bar item when reopening an already-running app (#114)

---

### 修复

- **增强模式现在会尊重你的 `tun.stack` 设置** — 之前生成的 `.enhanced_config.yaml` 硬编码 `stack: mixed`，会静默覆盖用户配置的 `tun.stack`。如果你配置了 `system`（或 `gvisor`），控制台却显示 `mixed`，改回去也不生效。现在 ClashFX 会从源配置读取 `tun.stack`，按 `system`/`gvisor`/`mixed`（不区分大小写）校验，仅在未设置或非法时才回退到 `mixed`。内置核心与外部核心两条路径使用同一个解析结果，不会再不一致。(#115)
- **控制台主题与列设置现在能持久保存** — 增强模式下外部控制器每次启动都分配随机端口，导致 Yacd 控制台的 origin（`127.0.0.1:端口`）每次都变，其按 origin 隔离的 `localStorage`（主题、自定义列）看起来被重置。现在 ClashFX 固定使用稳定的控制器端口（`19090`），仅当该端口被占用时才回退到随机空闲端口，从而让控制台 origin —— 以及你保存的偏好 —— 在多次启动间保持稳定。(#115)
- **增强模式启动更稳健** — 开启增强模式时，若外部核心绑定失败（例如瞬时端口竞争，或残留的 `mihomo_core` 进程仍占用控制器端口），现在会自动重试一次。每次重试都会用新端口重新生成配置，而不是直接报错，因此开启增强模式更不容易失败、无需手动重试。
- **重新打开 ClashFX 时会弹出菜单栏图标** — 当 ClashFX 已在运行、你又从访达 / Spotlight / 启动台 / Dock 再次打开它时，现在会自动弹出菜单栏菜单，方便你定位图标 —— 在菜单栏拥挤、图标被隐藏时尤其有用。感谢 @hangox 的建议。(#114)

### 贡献者

- @hangox — 建议在重复打开已运行的 app 时显示菜单栏项 (#114)
