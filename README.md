# 回家了么 (Go Home)

**帮助每一个走失的生命回家**

一个基于 Flutter 开发的公益寻亲平台，帮助走失的亲人、小孩、宠物等找到回家的路。本项目绝大部分代码由 **Claude AI** 辅助编写，是一次 AI 驱动开发的公益实践。

## 主要功能

- **发布寻亲/寻物启事** — 支持发布走失亲人、儿童、宠物、物品等分类信息，可上传多张照片、填写详细特征描述和走失地点
- **浏览与搜索** — 按分类筛选、关键词搜索，快速查找相关启事
- **提供线索** — 看到疑似走失者可在线提交线索，系统自动通知发布者
- **实时聊天室** — 支持文字、图片、语音、视频等多种消息类型，方便志愿者实时沟通协作
- **消息通知** — 线索回复、审核结果、系统通知等实时推送
- **多语言支持** — 中文 / English
- **内容审核** — 所有启事经人工审核后展示，保障信息真实性

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.x |
| 状态管理 | Provider |
| 网络请求 | Dio |
| 实时通信 | WebSocket |
| 登录方式 | 账号密码 / Apple Sign-In |
| 多媒体 | image_picker / video_player / record |
| 国际化 | intl + flutter_localizations |

## 项目结构

```
lib/
├── config/       # 配置（API 地址、路由、主题）
├── models/       # 数据模型
├── pages/        # 页面
│   ├── auth/     # 登录注册
│   ├── home/     # 首页信息流
│   ├── post/     # 发布 / 详情 / 搜索
│   ├── chat/     # 聊天室
│   ├── clue/     # 线索提交
│   ├── profile/  # 个人中心
│   └── message/  # 消息通知
├── providers/    # 状态管理
├── services/     # API 服务层
├── widgets/      # 通用组件
├── utils/        # 工具类
└── l10n/         # 国际化
```

## 快速开始

```bash
# 1. 克隆项目
git clone https://github.com/<your-username>/go-home.git
cd go-home/flutter_app

export PATH="$PATH:/Users/lang/flutter/bin"

# 2. 安装依赖
flutter pub get

# 3. 运行项目
flutter run
```
flutter build apk --release 2>&1
flutter build ios --release 2>&1
> 后端 API 地址在 `lib/config/api.dart` 中配置，开发环境默认连接 `http://127.0.0.1:8080`。

## 如何参与贡献

这是一个公益项目，欢迎每一位开发者贡献自己的力量！无论是修复 Bug、优化体验还是新增功能，每一份贡献都有意义。

### 参与方式

1. **Fork** 本仓库
2. 创建你的功能分支：`git checkout -b feature/your-feature`
3. 提交你的修改：`git commit -m "feat: 添加某某功能"`
4. 推送到远程：`git push origin feature/your-feature`
5. 提交 **Pull Request**

### 当前可以改进的方向

- [ ] 地图集成 — 在启事中展示走失地点地图
- [ ] 推送通知 — 接入 FCM/APNs 实现离线推送
- [ ] 附近的人 — 基于定位展示附近的寻亲启事
- [ ] 数据统计 — 找回成功率等数据可视化
- [ ] 无障碍优化 — 提升 Accessibility 支持
- [ ] 单元测试 — 补充测试覆盖率
- [ ] Android 适配 — 当前主要面向 iOS 和 Web，需要完善 Android 支持
- [ ] 后端开源 — 配套后端服务的开源计划

欢迎在 [Issues](../../issues) 中提出建议或认领任务。

## 关于本项目

本项目绝大部分代码由 **Claude AI** 辅助生成，是一次探索 AI 辅助开发公益产品的尝试。我们相信技术应该服务于社会，哪怕只是帮助一个人找到回家的路，这个项目就有意义。

如果你认同这个理念，欢迎 Star、Fork、参与开发，或者将这个项目分享给更多人。

## License

MIT License - 详见 [LICENSE](LICENSE) 文件
