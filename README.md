# VoiceCapturePro

> 为 iPhone 设计的专业双轨道录音器，支持同时捕获**系统声音**（微信通话等）和**麦克风**，两路分别保存为独立音轨，支持后期分离混音。

---

## 核心功能

| 功能 | 说明 |
|------|------|
| 🎙️ 双轨道全捕获 | 系统音频 + 麦克风分别录入独立 `.caf` 文件 |
| 🔇 纯麦克风模式 | 立即开始，无需系统授权弹窗 |
| 🎚️ 五档音质 | 从 AAC 64kbps 到 PCM 24bit/48kHz 无损 |
| 📂 录音库管理 | 搜索、筛选、标签、导出、删除 |
| 📍 位置 + 备注 | 自动记录地点，支持手动备注和标签 |
| 🎵 内置播放器 | 15秒快进/快退，进度条拖拽 |
| ⚡ 多种触发方式 | App 按钮 / 控制中心 / Siri 快捷指令 |

---

## 系统音频捕获原理（为什么耳机也能用）

本 App 使用 **ReplayKit Broadcast Upload Extension** 捕获系统声音。

ReplayKit 在**软件音频混合层**拦截音频流，这发生在 iOS 将音频路由到物理输出设备之前。因此：

- ✅ **扬声器模式** – 完全支持
- ✅ **有线耳机（Lightning/USB-C）** – 完全支持
- ✅ **AirPods / 蓝牙耳机** – 完全支持
- ✅ **通话录音（微信、FaceTime 等）** – 支持（扬声器/耳机均可）

---

## 项目结构

```
VoiceCapturePro/
├── .github/workflows/build.yml   # GitHub Actions CI（生成无签名 IPA）
├── project.yml                   # XcodeGen 项目配置
├── Shared/                       # 主 App 和扩展共享代码
│   └── AppGroupConstants.swift   # App Group ID 等常量
├── VoiceCapturePro/              # 主 App Target
│   ├── Sources/
│   │   ├── App/                  # 应用入口、TabView
│   │   ├── Views/                # SwiftUI 界面
│   │   ├── Engine/               # AVAudioRecorder 引擎（纯麦克风模式）
│   │   ├── Models/               # Recording 数据模型 + JSON 持久化
│   │   └── Managers/             # RecordingManager, LocationManager, BroadcastManager
│   └── Resources/
│       └── Assets.xcassets/
└── BroadcastExtension/           # 系统音频捕获扩展
    └── Sources/SampleHandler.swift
```

---

## ⚠️ 首次配置必读

### 1. 替换 Bundle ID

在以下文件中将 `com.vcpro.recorder` 替换为您自己的唯一 Bundle ID：

| 文件 | 修改位置 |
|------|---------|
| `project.yml` | `PRODUCT_BUNDLE_IDENTIFIER`（主 App 和扩展） |
| `Shared/AppGroupConstants.swift` | `appGroupID`、`broadcastBundleID` |
| `VoiceCapturePro/VoiceCapturePro.entitlements` | App Group 字符串 |
| `BroadcastExtension/BroadcastExtension.entitlements` | App Group 字符串 |

Bundle ID 格式建议：`com.你的姓名.voicecapture`

### 2. 注册 App Group（免费账号即可）

1. 打开 [Apple Developer 后台](https://developer.apple.com/account/)（免费账号登录）
2. 进入 **Certificates, Identifiers & Profiles → Identifiers**
3. 创建一个 **App Group**，ID 与您在代码中填写的一致
4. 将该 App Group 关联到您的 App ID 和 Extension App ID

### 3. 在 Sideloadly/AltStore 签名时选择正确 App Group

安装工具会使用您的 Apple ID 开发证书自动重签名，App Group 会被自动包含在 provisioning profile 中。

---

## 构建方式

### 方式 A：GitHub Actions（推荐，全自动）

1. 将本项目推送到 GitHub
2. Actions 自动运行 → 生成 **无签名 IPA**
3. 在 Actions → Artifacts 下载 IPA

### 方式 B：本地（需要 Mac + Xcode 15）

```bash
# 安装 XcodeGen
brew install xcodegen

# 生成 .xcodeproj
xcodegen generate --spec project.yml

# 用 Xcode 打开（推荐，可设置签名团队）
open VoiceCapturePro.xcodeproj
```

---

## 安装到 iPhone（无需 App Store）

| 方式 | 要求 | 有效期 |
|------|------|--------|
| **AltStore** | Mac/PC + AltServer + 免费 Apple ID | 7天（可自动刷新） |
| **Sideloadly** | Mac/PC + 免费 Apple ID | 7天 |
| **TrollStore** | iOS 14–17（部分版本/机型） | 永久 |

---

## 使用说明

### 双轨全捕获（录制微信通话等）

1. 在主界面选择**「双轨全捕获」**模式
2. 点击红色录音按钮 → 系统弹出广播授权弹窗
3. 点击**「开始直播」**
4. 开始微信通话（或其他 App）
5. 停止录音：**控制中心 → 点击红色录音状态条 → 停止**
6. 录音自动保存到「录音库」，包含两个独立文件：
   - `XXXX_mic.caf`  – 麦克风音轨
   - `XXXX_sys.caf`  – 系统音频音轨

### 纯麦克风模式（立即录制）

1. 选择**「纯麦克风」**模式
2. 点击录音按钮 → 立即开始
3. 再次点击 → 停止并保存

### 导出双轨文件

- 在录音库长按卡片 → **「导出 / 分享」**
- 通过 AirDrop、Files、邮件等分享两个 `.caf` 文件
- 导入 GarageBand、Logic Pro、Audacity 等进行双轨分离混音

---

## 录音质量对照

| 等级 | 格式 | 采样率 | 码率 | 适用场景 |
|------|------|--------|------|---------|
| 普通 | AAC | 22kHz | 64kbps | 语音记录，省空间 |
| 标准 | AAC | 44.1kHz | 128kbps | 日常录音 |
| 高质量 | AAC | 44.1kHz | 256kbps | **推荐，通话录音** |
| 专业 | AAC | 48kHz | 320kbps | 高质量语音 |
| 无损 | PCM | 48kHz | 24bit | 音乐/专业需求，文件大 |

> **注意**：Broadcast Extension 内部始终以 48kHz/16bit PCM 捕获系统音频和麦克风，以确保最高保真度。音质设置主要影响纯麦克风模式的输出格式。

---

## 技术说明

- **系统音频捕获**：`RPBroadcastSampleHandler` — `RPSampleBufferTypeAudioApp`
- **麦克风捕获**：`RPBroadcastSampleHandler` — `RPSampleBufferTypeAudioMic`（扩展内）/ `AVAudioRecorder`（主 App 纯麦模式）
- **双轨写入**：每路独立的 `AVAssetWriter` + `AVAssetWriterInput`
- **进程间通信**：Darwin Notification Center + App Group UserDefaults
- **位置**：`CoreLocation` + 逆地理编码
- **持久化**：JSON + App Group 共享容器（`RecordingsStore`）
