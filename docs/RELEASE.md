# AIO Studio 发版指南

## 版本号管理

项目采用 [语义化版本](https://semver.org/lang/zh-CN/)（Semantic Versioning），格式为 `X.Y.Z`。

发版前需确保以下位置的版本号一致：

| 文件 | 字段 | 格式 |
|------|------|------|
| `pubspec.yaml` | `version` | `X.Y.Z+BUILD` |
| `pubspec.yaml` | `msix_config.msix_version` | `X.Y.Z.0` |
| `extension/package.json` | `version` | `X.Y.Z` |
| `extension/manifest.json` | `version` | `X.Y.Z` |

## 发版流程

1. **更新版本号** — 修改上述所有文件中的版本号
2. **更新 CHANGELOG** — 在 `CHANGELOG.md` 中记录本次变更
3. **提交代码** — `git add . && git commit -m "chore: bump version to X.Y.Z"`
4. **打标签** — `git tag vX.Y.Z`
5. **推送** — `git push origin main --tags`

推送标签后，GitHub Actions 会自动：

- 校验所有文件中的版本号是否与标签一致
- 并行构建 Windows / macOS / Linux / Android / iOS / 浏览器扩展
- 创建 GitHub Release 并上传所有构建产物

也可以通过 GitHub Actions 页面手动触发 `workflow_dispatch`，填入版本号（可选）进行发布。

## CI/CD 工作流

### CI（`.github/workflows/ci.yml`）

触发条件：push 到 `main` / `develop` 分支，或向 `main` 提交 Pull Request。

| Job | 内容 |
|-----|------|
| `flutter-check` | 依赖安装 → 代码生成 → `flutter analyze` → `flutter test` |
| `extension-check` | `npm ci` → `npm run build`（TypeScript 编译 + Vite 构建） |

相同 ref 上的后续 push 会自动取消前一次正在运行的 CI（`concurrency` + `cancel-in-progress`）。

### Release（`.github/workflows/build.yml`）

触发条件：推送 `v*` 标签，或手动 `workflow_dispatch`。

| Job | Runner | 内容 |
|-----|--------|------|
| `validate-version` | ubuntu | 校验标签版本与项目文件版本一致 |
| `build-windows` | windows | Flutter Windows 构建 + MSIX（可选） |
| `build-macos` | macos | Flutter macOS 构建 |
| `build-linux` | ubuntu | Flutter Linux 构建 + tar.gz 打包 |
| `build-android` | ubuntu | Flutter Android APK 构建 |
| `build-ios` | macos | Flutter iOS IPA 构建（未签名） |
| `build-extension` | ubuntu | 浏览器扩展构建 + zip 打包 |
| `release` | ubuntu | 收集所有产物 → 创建 GitHub Release |

构建依赖关系：`validate-version` 通过后，所有 `build-*` job 并行执行；全部成功后 `release` job 收集产物并发布。

## Release 产物

| 文件名 | 说明 |
|--------|------|
| `aio-studio-windows-x64-vX.Y.Z.zip` | Windows 桌面版（exe 目录） |
| `aio-studio-macos-vX.Y.Z.zip` | macOS 桌面版（.app） |
| `aio-studio-linux-x64-vX.Y.Z.tar.gz` | Linux 桌面版 |
| `aio-studio-android-vX.Y.Z.apk` | Android APK |
| `aio-studio-extension-vX.Y.Z.zip` | 浏览器扩展（Chrome / Edge） |

## 当前签名状态

| 平台 | 签名状态 | 用户注意事项 |
|------|----------|-------------|
| Windows | 未签名 | 用户可能收到 SmartScreen 警告，选择"仍要运行"即可 |
| macOS | 未签名 | 需执行 `xattr -cr AIO\ Studio.app` 移除隔离属性 |
| Linux | 不适用 | — |
| Android | Debug 签名 | 仅供测试安装，不适合商店分发 |
| iOS | 未签名 | 仅供开发测试 |

## 配置正式签名（可选）

如需正式签名分发，在 GitHub 仓库 **Settings → Secrets and variables → Actions** 中配置以下 Secrets。工作流中已预留了对应的集成点，配置后可启用签名步骤。

### Android

| Secret | 说明 |
|--------|------|
| `ANDROID_KEYSTORE_BASE64` | Base64 编码的 `.jks` / `.keystore` 文件 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | key 别名 |
| `ANDROID_KEY_PASSWORD` | key 密码 |

### macOS

| Secret | 说明 |
|--------|------|
| `MACOS_CERTIFICATE_BASE64` | Base64 编码的 `.p12` 开发者证书 |
| `MACOS_CERTIFICATE_PASSWORD` | 证书密码 |
| `MACOS_TEAM_ID` | Apple Developer Team ID |

### Windows

| Secret | 说明 |
|--------|------|
| `WINDOWS_CERTIFICATE_BASE64` | Base64 编码的代码签名证书（`.pfx`） |
| `WINDOWS_CERTIFICATE_PASSWORD` | 证书密码 |

## 版本校验脚本

版本校验由 `scripts/validate_version.sh` 执行，会在 Release 工作流最前端运行。它会：

1. 从 Git 标签或 `workflow_dispatch` 输入中提取目标版本
2. 校验是否符合 `X.Y.Z` 语义化版本格式
3. 逐一对比 `pubspec.yaml`、`extension/package.json`、`extension/manifest.json` 中的版本
4. 检查 `msix_config.msix_version` 是否为 `X.Y.Z.0` 格式（不一致时发出警告）
5. 任一核心版本不匹配时阻止发布
