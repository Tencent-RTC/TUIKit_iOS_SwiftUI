
Pod::Spec.new do |s|
    s.name             = 'ChatUIKit'
    s.version          = '3.4.0'
    s.summary          = 'Chat UIKit Component'
    s.homepage         = 'https://trtc.io/document/chat-overview?product=chat&menulabel=uikit&platform=ios%20and%20macos'
    s.license          = { :type => 'Proprietary',
    :text => <<-LICENSE
    copyright 2025 tencent Ltd. All rights reserved.
    LICENSE
    }
    s.author           = 'tencent video cloud'
    s.source           = { :git => 'https://github.com/Tencent-RTC/TUIKit_iOS_SwiftUI', :tag => s.version }
    s.ios.deployment_target = '14.0'
    s.swift_version    = '5.0'

    s.dependency 'Kingfisher'
    s.dependency 'AtomicXCore'
    s.dependency 'Masonry'
    s.dependency 'AtomicX/Chat'

    s.source_files     = '*.{swift,h,m}'

end
