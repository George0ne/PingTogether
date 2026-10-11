<div align="center">
  <img src="assets/textures/enemy_missing.png" width="96" alt="PingTogether 黄色问号图标">
  <h1>PingTogether</h1>
  <p>读到不懂的那句话？框一下，再 Ping 一下。</p>
  <p>A tiny native macOS app for desktop pings, sounds, and temporary highlights.</p>
</div>

PingTogether 把游戏里的 Ping 手感带到桌面。读论文、讲公式、共享屏幕时，用一个问号表达“这句我没懂”，再用浅色底纹说明“就是这里”。

这是独立运行的 macOS 菜单栏软件，不需要安装 LOL，也不依赖浏览器插件。当前版本完全本地运行，适合通过屏幕共享和朋友一起使用。

## 下载与安装

前往 [Releases](https://github.com/George0ne/PingTogether/releases) 下载最新 DMG，打开后将 **PingTogether.app** 拖到 **Applications**，再双击启动。菜单栏出现黄色问号后就可以使用。

- **系统**：macOS 12 或更新版本。
- **芯片**：Apple Silicon 与 Intel，通用架构应用。
- **版本**：0.5.0。
- 当前构建使用本地临时签名，尚未经过 Apple Developer ID 签名与公证。其他 Mac 首次启动可能受到系统安全检查限制。

## 主要功能

- **八向 Ping 轮盘**：按住快捷键唤出，移动鼠标划选，松开发送。
- **问号与提示音**：使用社区提供的 LOL 图标和音效；动画包含弹出、回弹、扩散圈和淡出。
- **轻量框选强调**：给一句话、公式或图片铺上半透明黄色底纹，并在旁边自动打问号。
- **六秒临时底纹**：不会成为永久批注，完成后不拦截鼠标点击。
- **菜单栏控制**：测试提示音、静音、查看说明与退出。
- **离线运行**：不上传文献，不录屏，不采集音频，没有登录和服务器。

## 快捷键

| 操作 | 快捷键 / 手势 |
| --- | --- |
| 打开轮盘 | **按住 Option + Q** |
| 选择并发送 Ping | 保持按住，移动鼠标选择，松开 Q 或 Option |
| 直接打问号 | **Control + Option + Q** |
| 框选底纹 + 问号 | **按一下 Option + A**，再用鼠标拖框，松开鼠标完成 |
| 清除底纹 | **Option + X** |
| 取消 | 轮盘中心松开、Esc 或右键；框选模式下 Esc / 右键 |

`Option` 就是键盘上的 `⌥`。

Ping 落在**唤出轮盘时**的鼠标位置；移动鼠标只用来选方向。轮盘从左侧问号开始，顺时针依次为：敌人不见了、敌方视野、危险、推进、正在路上、全力进攻、协助我、需要视野。

框选底纹保留 **6 秒**，最后 0.75 秒淡出。新底纹替换上一块。仅单击不拖动不会产生强调；进入框选后 30 秒未完成会自动退出。

## 和朋友一起看文献

1. 在会议或远程软件里共享**整个屏幕**。
2. 读到不懂的句子，按 `⌥A`，拖框圈住它。
3. 朋友看到底纹和问号；若共享软件开启了系统音频，也能听到提示音。
4. 翻页前按 `⌥X` 清除，或者等待底纹自动消失。

目前**没有好友联网同步**。仅共享某个应用窗口可能不包含独立浮层；声音转发由共享软件负责。

## 常见问题

**为什么没有声音？**

点击菜单栏黄色问号 → “测试提示音”。检查应用静音、macOS 系统静音、音量和输出设备。软件不会自行调整系统音量。

**底纹会跟随 PDF 滚动吗？**

不会。它使用屏幕坐标，不读取或修改 PDF 内容。滚动、缩放、移动窗口之前可先按 `⌥X` 清除。

**屏幕边缘为什么会裁切？**

轮盘中心固定在鼠标位置，靠近边缘时可能被裁切。将鼠标移离边缘再唤出即可。框选限定在触发快捷键时鼠标所在的显示器。

**怎么退出或卸载？**

点击黄色问号菜单 → “退出 PingTogether”。退出后，将 Applications 中的 App 移到废纸篓即可。

## 从源码构建

需要 macOS 和 Xcode Command Line Tools。没有 npm、Python 或第三方运行时依赖，构建时不下载素材。

```sh
bash build.sh
build/PingTogether.app/Contents/MacOS/PingTogether --self-test
open build/PingTogether.app
```

打包安装镜像：

```sh
bash package.sh
```

产物是 `dist/PingTogether-0.5.0-macOS.dmg` 与对应 SHA-256 文件。签名是本地临时签名，不等同于 Apple 公证。

实际声音诊断（会播放声音）：

```sh
build/PingTogether.app/Contents/MacOS/PingTogether --test-audio
```

## 给开发者与 AI

先阅读 [AGENTS.md](AGENTS.md)，其中包含代码入口、行为约定、验证步骤和已知限制。

| 文件 | 用途 |
| --- | --- |
| `src/main.m` | AppKit 菜单栏应用、全局快捷键、轮盘、音效、框选与自检 |
| `Info.plist` | 应用标识、最低系统版本、图标和版本号 |
| `build.sh` | 编译 arm64 / x86_64 通用应用、制作图标并临时签名 |
| `package.sh` | 自检、验签、制作 DMG 并生成校验文件 |
| `assets/` | 图标、声音、来源记录与校验清单 |
| `使用说明.txt` | 随安装包提供的简短说明 |

## 素材与致谢

图标、问号及音效来自 [darrenprx/lolPing](https://github.com/darrenprx/lolPing) 的公开素材，上游标注为从 League of Legends 提取、权利归 **Riot Games** 所有。具体版本、原始 URL 与 SHA-256 见 [assets/SOURCES.md](assets/SOURCES.md) 和 [assets/manifest.json](assets/manifest.json)。

这些游戏素材**不属于上游代码的 MIT 许可范围**。本项目不宣称获得 Riot Games 的授权、赞助或背书；公开仓库也不转移第三方素材的权利。当前没有为本项目原创代码声明统一的开源许可证。
