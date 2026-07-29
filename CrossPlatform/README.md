# MinimalAIChat Android

这是 MinimalAIChat 的 Android Flutter 客户端，仅用于构建 APK。iOS SwiftUI 工程继续保留在仓库根目录。

## 已实现

- OpenAI / OpenRouter 兼容 API
- 中文界面、多话题和本地聊天记录
- 10 个推荐模型、自定义模型与 OpenRouter 在线模型列表
- 模型图片/文件能力及审查标记搜索
- Tavily 联网搜索
- 图片、PDF、文本和其他文件附件
- 双方名字与头像
- 酒馆 JSON / PNG 角色卡
- 系统提示词、角色提示词、主题色和自定义背景

## 构建

GitHub Actions 中运行 `Build Android APK`，完成后从该次运行的 Artifacts 下载 APK。
