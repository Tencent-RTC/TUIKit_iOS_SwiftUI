一 如果您在使用录制的时候提示"由于您的工程配置，您当前功能将受限...",这是因为视频录制的某些功能需要用到TXLiteAVSDK_Professional，而当前缺失该依赖。

解决方法1：
在您的项目中依赖最新的TXLiteAVSDK_Professional，如果您的项目已经有依赖TXLiteAVSDK_TRTC，则将其替换为TXLiteAVSDK_Professional
TXLiteAVSDK_Professional完全包含了TXLiteAVSDK_TRTC，用其替换TXLiteAVSDK_TRTC不会让您其他的功能有任何的变化

解决方法2:
您可以在配置代码中屏蔽引起弹窗的相关功能
配置文件位置：Resources/assets/chat/VideoRecorder.bundle/config/default_config.json，配置文件如下:
{
  "max_record_duration_ms": "15000",
  "min_record_duration_ms": "2000",
  "video_quality": "2",
  "primary_theme_color": "#147AFF",
  "is_default_front_camera":"false",
  "record_mode":"0",
  "support_record_torch": "true",
  "support_record_beauty": "true",
  "support_record_aspect": "true",
}

比如您如果想屏蔽美颜功能，将support_record_beauty项设置为false即可。如果没有依赖TXLiteAVSDK_Professional你可能需要屏蔽support_record_beauty，support_record_aspect



二 如果您在使用录制的时候提示"由于您未开通多媒体插件使用权限，您当前功能将受限...",这是因为视频录制的某些功能需要注册开通

解决方法1：
注册开通视频录制的高级功能并了解更多详细功能，请访问官方文档：https://cloud.tencent.com/document/product/269/113290
解决方法2：
屏蔽部份功能，屏蔽方法如问题一的解决方法2，您需要屏蔽support_record_beauty

  
  
I. If you encounter the prompt "Due to your project configuration, your current features will be restricted..." while using the recording function, this is because certain video recording features require the use of TXLiteAVSDK_Professional, which is currently missing as a dependency.

Solution 1:  
In your project, depend on the latest version of TXLiteAVSDK_Professional. If your project already depends on TXLiteAVSDK_TRTC, replace it with TXLiteAVSDK_Professional.  
LiteAVSDK_Professional fully includes TXLiteAVSDK_TRTC. Replacing TXLiteAVSDK_TRTC with it will not cause any changes to your other functionalities.

Solution 2:  
You can disable the relevant features that trigger the prompt in the configuration code.  
Configuration file location: Resources/assets/chat/VideoRecorder.bundle/config/default_config.json. The configuration file is as follows:  
{  
  "max_record_duration_ms": "15000",  
  "min_record_duration_ms": "2000",  
  "video_quality": "2",  
  "primary_theme_color": "#147AFF",  
  "is_default_front_camera": "false",  
  "record_mode": "0",  
  "support_record_torch": "true",  
  "support_record_beauty": "true",  
  "support_record_aspect": "true",  
}  

For example, if you want to disable the beauty filter feature, set the "support_record_beauty" item to false. If you do not depend on TXLiteAVSDK_Professional, you may need to disable "support_record_beauty" and "support_record_aspect".

II. If you encounter the prompt "Due to your failure to activate the multimedia plugin usage permissions, your current features will be restricted..." while using the recording function, this is because certain video recording features require registration and activation.

Solution 1:  
To register and activate the advanced features of video recording and learn more about the detailed functionalities, please visit the official documentation: https://cloud.tencent.com/document/product/269/113290  

Solution 2:  
Disable some features. The method to disable them is the same as Solution 2 for Issue I. You need to disable "support_record_beauty".