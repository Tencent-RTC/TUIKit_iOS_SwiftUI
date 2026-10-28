中文版本
# 纵横比设置

视频录制不提供美颜功能，也不获取录制插件签名。录制参数通过 `VideoRecorderConfig` 设置，不再支持 JSON 配置文件或 JSON 字符串。

纵横比设置需要 TXLiteAVSDK_Professional。在项目或任一模块的 Podfile 中添加依赖：

```ruby
pod 'TXLiteAVSDK_Professional'
```

- 如果工程已依赖 TXLiteAVSDK_TRTC，可替换为 TXLiteAVSDK_Professional。
- 未提供 UGC 录制核心时使用系统录制，纵横比按钮自动隐藏。
- 普通拍摄、闪光灯、切换摄像头、预览和确认功能保留。
- 底层录制失败仍按错误处理，不跳过 SDK 的校验。

English Version
# Aspect Ratio Settings

Video recording does not provide beauty effects or fetch recording plugin signatures. Set recording parameters through `VideoRecorderConfig`; JSON configuration files and JSON strings are no longer supported.

Aspect ratio settings require TXLiteAVSDK_Professional. Add the dependency in the project's or a module's Podfile:

```ruby
pod 'TXLiteAVSDK_Professional'
```

- TXLiteAVSDK_TRTC can be replaced with TXLiteAVSDK_Professional.
- When the UGC recording core is unavailable, the system recorder is used and the aspect ratio button is hidden.
- Capture, flash, camera switching, preview and confirmation remain available.
- Recording failures remain errors; SDK validation is not bypassed.
