# Carl's Player

原生 macOS 本地媒体播放器。打开一个文件夹，侧栏以缩略图列出视频与音频，点击即可播放。

## 功能

- 打开本地文件夹，扫描其中的视频与音频
- 侧栏缩略图列表，可调节宽度与缩略图大小
- 播放 / 暂停、进度拖动、音量控制
- 三种播放模式：顺序播放、列表循环、单曲循环
- 深色界面，适配 macOS 原生窗口工具栏

## 支持格式

| 类型 | 扩展名 |
|------|--------|
| 视频 | `mp4` `mov` `m4v` `avi` |
| 音频 | `mp3` `m4a` `aac` `wav` `aiff` |

## 要求

- macOS 14.0+
- Xcode 16+（建议使用与工程一致的较新版本）

## 构建与运行

用 Xcode 打开工程：

```bash
open mPlayer.xcodeproj
```

选择 scheme `mPlayer`，目标设为 **My Mac**，然后 Run（⌘R）。

命令行 Release 构建示例：

```bash
xcodebuild -project mPlayer.xcodeproj -scheme mPlayer -configuration Release \
  -destination 'generic/platform=macOS' CODE_SIGN_IDENTITY="-" build
```

## 快捷键

| 快捷键 | 作用 |
|--------|------|
| ⌘O | 打开文件夹 |
| Space | 播放 / 暂停 |

## 项目结构

```
mPlayer/
├── mPlayerApp.swift          # 应用入口
├── Models/                   # 媒体项、播放模式
├── Services/                 # 媒体库扫描、播放控制、缩略图
├── Views/                    # 侧栏、播放器、控制条
└── Utilities/                # 布局与时间格式化
```

## 许可

个人项目，按需使用。
