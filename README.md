# 道闸管家 GateLAN

这是一个面向授权维护场景的 iOS 16+ SwiftUI App。它可以保存你自己的道闸后台地址和账号，检测设备端口是否在线，并通过内置 WebView 打开后台。

不会做的事：

- 不内置品牌默认账号密码
- 不扫描后台路径
- 不自动尝试登录
- 不爆破或测试弱口令

## 功能

- 手动添加 IP/主机名、端口、协议、路径、品牌和备注
- 选择常见道闸/安防品牌模板，仅填充名称、端口、路径
- 使用 iOS Keychain 保存你自己录入的授权凭据
- 使用 Bonjour/mDNS 发现局域网内公开广播的 HTTP/HTTPS 服务
- 启动时主动触发 iOS 本地网络权限请求
- TCP 在线检测
- WKWebView 打开设备后台

## 打包 IPA

需要在 macOS + Xcode 上构建：

```sh
chmod +x build-ipa-macos.sh
./build-ipa-macos.sh
```

脚本会生成 `GateLAN.ipa`。如果你用 TrollStore 安装，按你的本机流程对 IPA 签名或直接导入安装。

## iOS 版本

最低部署目标是 iOS 16.0，适配你的 iOS 16.6.1。
