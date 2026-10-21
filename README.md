# TuckBar · 藏栏

<img src="Resources/TuckBar.iconset/icon_128x128@2x.png" width="128" alt="TuckBar logo">

**把不常用的菜单栏图标收起来，需要时一键展开。**

A small native macOS menu bar utility. Command-drag icons into a collapsible region, then click to tuck them away or reveal them.

![Platform: macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

## 功能

- 仅驻留菜单栏，无 Dock 图标，原生 AppKit 界面。
- 点击箭头展开 / 收起隐藏区。
- 使用 macOS 自带的 **⌘ + 拖动** 整理图标位置。
- 右键箭头打开操作菜单、使用说明或退出。
- 根据最宽的已连接显示器计算隐藏区宽度，显示器变化和唤醒时重新计算。
- 首次启动展开以便整理，整理完成后启动默认收起；展开 15 秒后自动收起，打开整理窗口时暂停计时。退出时恢复菜单栏空间。
- 无第三方依赖、无联网代码，不需要辅助功能或屏幕录制权限。

## 构建与运行

需要 **macOS 13+** 和 **Swift 6 工具链**（例如 Xcode 16+）。

```sh
git clone https://github.com/yestark/TuckBar.git
cd TuckBar
./scripts/build-app.sh
open dist/TuckBar.app
```

产物位于 `dist/TuckBar.app`，可复制到「应用程序」文件夹。可以用 Xcode 打开 `Package.swift` 阅读和调试；日常使用建议运行脚本生成的 App bundle。

构建脚本生成当前 Mac 架构的二进制，并进行本地 ad-hoc 签名。当前版本没有 Developer ID 签名或 Apple 公证；不提供已公证安装包。

## 使用

1. 启动后会出现分隔线 `│` 和箭头。
2. 按住 **⌘**，把 `│` 拖到 TuckBar 箭头左边。
3. 将想隐藏的图标拖到分隔线左侧；常用图标放在分隔线与箭头之间或箭头右侧。
4. 点击「整理完成，收起图标」，或点击菜单栏箭头收起，再点一下展开。展开 15 秒后自动收起，右键箭头可退出或重新整理。

```text
隐藏区图标     │     常用图标     ‹     系统图标
   收起区域     分隔线           TuckBar
```

收起时分隔线本身也会消失，只留下 TuckBar 展开按钮。

菜单栏位置由 macOS 管理。首次摆放后，系统通常会保留位置；若顺序变化，重新按住 ⌘ 拖动即可。TuckBar 会检查分隔线位置，顺序不对时提示整理，不会主动收起。

## 刘海屏与系统限制

**展开不等于额外增加菜单栏空间。** 刘海屏右侧空间不足时，即使展开，部分图标仍可能被刘海遮挡或无法显示。减少常驻图标、切到菜单较少的 App 或使用更宽的外接显示器可能有帮助。

首版没有独立的第二行图标面板，也不保证所有隐藏图标能同时显示。这是基于原菜单栏展开的轻量实现，不是图标镜像工具。

macOS 没有公开接口让一个 App 任意隐藏、重新排列其他 App 的菜单栏图标。TuckBar 通过调整自身分隔项宽度，把左侧区域挤出可见范围；移动使用系统的 ⌘ 拖动。时钟、控制中心及某些 App 的图标不可自由移动或隐藏。系统版本变化可能影响这一几何方式的表现。

## 开发与验证

```sh
swift test
./scripts/build-app.sh
codesign --verify --deep --strict dist/TuckBar.app
```

自动化测试覆盖展开/收起状态、首次整理与整理后启动状态、外接屏宽度变化、无显示器回退和宽度上限。菜单栏布局由 macOS 的 WindowServer 管理，仍需要真机手动验证：

- [ ] 首次运行，按 ⌘ 拖动分隔线和第三方图标。
- [ ] 点击收起和展开，常用图标与按钮保持可见。
- [ ] 把分隔线拖到箭头右侧，确认收起被拦截。
- [ ] 右键菜单和使用说明可操作，关闭说明后应用继续驻留。
- [ ] 刘海屏、大量图标、外接显示器、拔插和休眠唤醒。
- [ ] 退出后隐藏区图标恢复，重新启动默认收起。

GitHub Actions 在 macOS runner 上运行测试并编译 App。

应用图标由 `scripts/make-icon.swift` 使用 AppKit 绘制，原生 `.icns` 与多尺寸 PNG 保存在 `Resources/`。可编辑脚本后用 `swift scripts/make-icon.swift` 和 `iconutil -c icns Resources/TuckBar.iconset -o Resources/TuckBar.icns` 重新生成。

可选诊断：从终端执行 `./dist/TuckBar.app/Contents/MacOS/TuckBar --diagnostics`，会向标准输出报告本应用自身的分隔项宽度、按钮位置和展开状态，不读取其他 App 或捕获屏幕。运行前先退出已有实例。

## 实现参考

采用公开的 AppKit `NSStatusBar` / `NSStatusItem` 接口。几何隐藏方案也见于 [Hidden Bar 的架构说明](https://github.com/dwarvesf/hidden/blob/develop/docs/ARCHITECTURE.md)。TuckBar 的实现独立编写，不包含其源代码。

## License

[MIT](LICENSE) © 2026 yestark
