# FishCopy 自动发布指南

## 自动化DMG构建和发布流程

通过GitHub Actions，你可以自动构建和发布应用的DMG安装包。整个过程已配置完成，只需按照以下步骤操作即可：

### 发布新版本的步骤

1. 确保所有代码更改已经提交并推送到GitHub

2. 在本地创建新版本标签并推送：
   ```bash
   # 例如，发布v1.0.0版本
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. 当标签推送到GitHub后，GitHub Actions工作流将自动触发

4. 工作流会执行以下操作：
   - 构建macOS应用
   - 创建DMG文件
   - 发布新版本到GitHub Releases
   - 上传DMG文件作为发布资产

5. 几分钟后，你可以访问GitHub仓库的"Releases"页面查看新发布的版本

### 设置GitHub Secrets

为了正确签名和公证应用，你需要在GitHub仓库中设置以下密钥：

1. 访问GitHub仓库的"Settings" > "Secrets and variables" > "Actions"
2. 点击"New repository secret"添加以下密钥：

**基本配置（必需）**：
- `TEAM_ID`：你的Apple开发者团队ID

**代码签名（如需签名应用）**：
- `DEVELOPER_ID_CERTIFICATE_BASE64`：Base64编码的开发者ID证书（.p12格式）
   ```bash
   # 将证书转换为Base64格式的命令
   base64 -i DeveloperIDCertificate.p12 | pbcopy
   ```
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`：证书密码
- `KEYCHAIN_PASSWORD`：临时密钥链的密码（可以自行设置任意值）

**公证（如需公证应用）**：
- `APPLE_ID`：用于公证的Apple ID
- `APPLE_APP_SPECIFIC_PASSWORD`：App专用密码（在Apple ID网站生成）

### 选择合适的工作流

项目中提供了两个工作流文件：

1. **基本版本**（`.github/workflows/macos-release.yml`）：
   - 仅构建和打包应用，不包含签名和公证
   - 适合初期测试和内部使用

2. **高级版本**（`.github/workflows/macos-release-advanced.yml`）：
   - 包含完整的代码签名和公证流程
   - 适合正式发布的应用

要使用高级版本，请在GitHub仓库上启用它：
1. 访问"Actions"标签页
2. 点击"I understand my workflows, go ahead and enable them"
3. 选择"Build and Release macOS App (Advanced)"工作流

### 查看构建进度

你可以在GitHub仓库的"Actions"标签页查看构建进度和日志。如果构建失败，你可以在此处查看详细错误信息。

### 修改发布配置

如需修改发布工作流的配置，可编辑`.github/workflows/macos-release.yml`或`.github/workflows/macos-release-advanced.yml`文件：

- 修改触发条件（例如，从特定分支发布）
- 自定义DMG文件的外观
- 更改发布说明模板

### 注意事项

- 确保Xcode项目配置正确，特别是证书和签名设置
- 对于App Store发布，你需要修改工作流以使用`xcodebuild -exportArchive`并设置适当的导出选项
- GitHub Actions有每月免费使用时间限制，大型项目可能会超出免费额度
- 使用高级版本前，请先在本地测试应用的签名和公证流程，确保配置正确

### 手动修复发布问题

如果自动发布失败，你仍可以按照以下步骤手动创建DMG：

1. 在Xcode中选择Product > Archive
2. 在Archives窗口中，点击"Distribute App"
3. 选择"Copy App"并保存到本地
4. 使用Disk Utility或create-dmg工具创建DMG
5. 手动上传DMG到GitHub Releases页面 