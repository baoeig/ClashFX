### Bug Fixes

- **Status Bar Speed Recovery** — The menu bar upload/download speed display now recovers when the traffic or log WebSocket closes cleanly, stalls without an error, or becomes stale after macOS sleep/wake.
- **Network Change Recovery** — ClashFX now resets the traffic stream after local IP/interface changes so the menu bar speed indicator does not stay frozen after switching Wi-Fi, VPN, or network environments.
- **Remote Subscription Compatibility** — Remote config downloads now use a Clash Meta-compatible User-Agent, fixing providers that returned only base64/share-link node lists instead of full YAML rules and proxy groups.
- **Legacy TUN Route Exclusions** — Enhanced Mode now automatically converts old LAN wildcard exclusions such as `10.*`, `192.168.*`, and `172.16.*`–`172.31.*` into valid CIDR ranges before generating the mihomo config. The Go config writer also accepts these legacy entries as a fallback.

---

### 修复

- **状态栏网速恢复** — 菜单栏上传/下载速度在 traffic/log WebSocket 正常关闭、无错误卡住，或 macOS 睡眠/唤醒后变成旧连接时，现在会自动恢复，不再长期定格。
- **网络变化恢复** — 本机 IP 或网络接口变化后，ClashFX 会重置流量流，避免切换 Wi-Fi、VPN 或网络环境后菜单栏网速继续冻结。
- **远程订阅兼容性** — 远程配置下载现在使用 Clash Meta 兼容的 User-Agent，修复部分机场只返回 base64/share-link 节点列表，导致规则和代理组丢失的问题。
- **旧版 TUN 路由排除兼容** — 增强模式会自动把 `10.*`、`192.168.*`、`172.16.*`–`172.31.*` 等旧局域网通配符转换成 mihomo 接受的 CIDR；Go 配置生成层也增加了兜底兼容。
