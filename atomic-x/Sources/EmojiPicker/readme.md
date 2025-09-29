# EmojiPicker 组件使用说明

## 依赖环境
- iOS 13.0 及以上
- 依赖 [BaseComponent] 和 [Kingfisher] 库

## 初始化与快速使用

### SwiftUI 方式
```swift
import EmojiPicker

EmojiPickerView(
    onEmojiClick: { emojiData in
        // 处理点击的表情
    },
    onSendClick: {
        // 处理发送按钮点击
    },
    onDeleteClick: {
        // 处理删除按钮点击
    }
)
```

### Service 方式（如需解耦调用）
```swift
let result = EmojiPickerService.shared.onCall(
    serviceName: "EmojiPicker",
    method: "getEmojiPickerView",
    param: [
        "onEmojiClick": { (emoji: EmojiData) in /* ... */ },
        "onSendClick": { /* ... */ },
        "onDeleteClick": { /* ... */ }
    ],
    result: nil
)
// result 即为 EmojiPickerView
```

## 主要类与方法说明

### EmojiPickerView
- `init(onEmojiClick:onSendClick:onDeleteClick:)`：主入口，回调分别对应表情点击、发送、删除。
- 展示最近使用（最多8个）和全部表情，支持点击、发送、删除。

### EmojiManager
- `static let shared`：单例。
- `func createAttributedStringFromEmojiData(_:)`：将 EmojiData 转为 NSAttributedString（带图片）。
- `func createAttributedStringWithTextAndStyle(text:withFont:textColor:)`：将带表情 name 的字符串转为富文本（图片+样式）。
- `func createAttributedStringFromEmojiCodes(from:)`：将字符串中的表情 code 转为图片。
- `func createLocalizedStringFromEmojiCodes(_:)`：将字符串中的表情 code 转为本地化 name。
- `func getRecentEmojis()`：获取最近使用的表情 name 列表。
- `func addRecentEmoji(_:)`：添加到最近使用。

### EmojiData
- `name`：表情唯一标识（如 [TUIEmoji_Smile]）。
- `localizableName`：本地化名称。
- `path`：本地图片路径。

### EmojiPickerService
- `static let shared`：单例。
- `func onCall(serviceName:method:param:result:)`：通用服务调用，支持方法：
    - `getEmojiPickerView`：获取 EmojiPickerView。
    - `createLocalizedStringFromEmojiCodes`：表情 code 转本地化名。
    - `createAttributedStringWithTextAndStyle`：字符串转富文本。
    - `createAttributedStringFromEmojiCodes`：字符串转图片富文本。

### EmojiConfig
- `static let shared`：表情配置单例。
- `emojiGroups`：全部表情分组。

### EmojiCache
- `static let shared`：表情图片缓存。
- `addEmojiToCache(_:)`：异步加载图片到缓存。
- `getImageFromCache(_:)`：获取缓存图片。

## 其他说明
- 最近使用表情自动本地持久化，最多8个。
- 支持自定义表情图片和本地化。

---
如需更多高级用法，请参考源码和接口注释。
