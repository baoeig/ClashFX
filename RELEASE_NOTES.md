### New Features

- **Built-in App Icons** — Appearance settings now include selectable built-in ClashFX app icons, with a Default option and custom uploads still supported.
- **Persistent Release App Icon Switching** — Release app bundles can persist Finder/Dock icon changes while Xcode/DerivedData builds stay session-only to avoid signing damage.

### Bug Fixes

- **Enhanced Mode Uses the Selected Config Path** — Enhanced Mode now resolves the active config through the same path logic as the rest of the app, including iCloud fallback handling.
- **Custom Icon Uploads Normalize to PNG** — Uploaded app icon images are converted to PNG before saving, avoiding mismatched file contents when users choose ICNS or other supported image formats.
- **Web Cache Cleanup Moved Off Main Thread** — Cookie and WebKit data cleanup now runs on a utility queue to avoid blocking startup UI work.

---
### 新功能

- **内置应用图标** — 外观设置现在提供多款内置 ClashFX 应用图标可选，同时保留默认图标和自定义上传。
- **Release 版应用图标持久切换** — Release app bundle 可以持久保存 Finder/Dock 图标变化；从 Xcode/DerivedData 运行时只做当前会话更新，避免破坏签名。

### 修复

- **增强模式使用当前选中配置路径** — 增强模式现在通过与 App 其他部分一致的路径逻辑解析当前配置，并处理 iCloud 路径不可用时的本地回退。
- **自定义图标上传统一保存为 PNG** — 上传应用图标时会先转换为 PNG 再保存，避免选择 ICNS 或其他支持格式时出现内容与文件扩展名不匹配。
- **Web 缓存清理移出主线程** — Cookie 和 WebKit 数据清理现在在 utility 队列执行，避免阻塞启动阶段 UI 工作。
