
Pod::Spec.new do |s|
    s.name             = 'ChatUIKit'
    s.version          = '4.2.0'
    s.summary          = 'SwiftUI chat entry components for AtomicX Chat.'
    s.description      = 'SwiftUI pages that provide conversation, contact, and chat entry points for AtomicX Chat.'
    s.homepage         = 'https://github.com/Tencent-RTC/TUIKit_iOS_SwiftUI'
    s.license          = { :type => 'Proprietary',
        :text => <<-LICENSE
        copyright 2025 tencent Ltd. All rights reserved.
        LICENSE
    }
    s.author           = 'tencent video cloud'
    s.source           = { :git => 'https://github.com/Tencent-RTC/TUIKit_iOS_SwiftUI.git', :tag => s.version.to_s }
    s.ios.deployment_target = '15.0'
    s.swift_version    = '5.0'

    s.dependency 'Kingfisher'
    s.dependency 'AtomicXCore'
    s.dependency 'AtomicX/Chat'

    s.source_files     = '*.{swift,h,m}'

end
