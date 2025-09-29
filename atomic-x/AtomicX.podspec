Pod::Spec.new do |s|
  s.name             = 'AtomicX'
  s.version          = '3.4.0'
  s.summary          = 'A collection of UI components and utilities for AtomicX.'
  s.homepage         = 'https://trtc.io/document/chat-overview?product=chat&menulabel=uikit&platform=ios%20and%20macos'
  s.license          = { :type => 'Proprietary',
    :text => <<-LICENSE
    copyright 2025 tencent Ltd. All rights reserved.
    LICENSE
  }
  s.author           = 'tencent video cloud'
  s.source           = { :git => 'https://github.com/Tencent-RTC/TUIKit_iOS_SwiftUI', :tag => s.version }
  s.ios.deployment_target = '13.0'

  # Main spec
  s.source_files     = 'Sources/**/*.{swift,h,m}'
  s.swift_version    = '5.0'
  s.frameworks       = 'UIKit', 'Foundation'

  s.dependency 'Kingfisher', '~> 7.0'
  s.dependency 'SnapKit'
  s.static_framework = true

  # Live
  s.subspec 'Live' do |live|
    live.dependency 'SVGAPlayer', '~> 2.5.7'
    live.dependency 'Protobuf', '~> 3.22.1'
    live.dependency 'TEBeautyKit'
    live.source_files     = 'Sources/**/*.{swift,h,m}'
    live.resource_bundles = {
      'AtomicXBundle' => ['Resources/assets/live/**/*.{xcassets,json,png}', 'Resources/strings/**/*.bundle']
    }
    live.dependency 'RTCRoomEngine_Plus'
  end 

   # Chat
  s.subspec 'Chat' do |chat|
    # chat.source_files     = 'Sources/**/*.{swift,h,m}'
    chat.source_files = [
        'Sources/AudioPlayer/*.{swift,h,m}',
        'Sources/BaseComponent/**/*.{swift,h,m}',
        'Sources/ChatSetting/*.{swift,h,m}',
        'Sources/ContactList/*.{swift,h,m}',
        'Sources/ConversationList/*.{swift,h,m}',
        'Sources/EmojiPicker/*.{swift,h,m}',
        'Sources/FilePicker/*.{swift,h,m}', 
        'Sources/ImagePicker/*.{swift,h,m}',
        'Sources/ImageViewer/*.{swift,h,m}',
        'Sources/MessageInput/*.{swift,h,m}',
        'Sources/MessageList/*.{swift,h,m}',
        'Sources/Search/*.{swift,h,m}',
        'Sources/VideoPicker/*.{swift,h,m}',    
        'Sources/VideoPlayer/*.{swift,h,m}',
        'Sources/AudioRecorder/**/*.{swift,h,m}',
        'Sources/VideoRecorder/**/*.{swift,h,m}',
        'Sources/UserPicker/**/*.{swift,h,m}'
    ]
    chat.resource_bundles = {
      'AtomicXBundle' => ['Resources/assets/chat/**/*.{xcassets,json,png}', 'Resources/strings/**/*.{bundle,xcstrings}']
    }
    chat.dependency 'AtomicXCore'
    chat.dependency 'Masonry'
  end 

   # Room
  s.subspec 'Room' do |room|
    room.source_files     = 'Sources/**/*.{swift,h,m}'
    room.resource_bundles = {
      'AtomicXBundle' => ['Resources/assets/room/**/*.{xcassets,json,png}', 'Resources/strings/**/*.{bundle,xcstrings}']
    }
  end 
end
