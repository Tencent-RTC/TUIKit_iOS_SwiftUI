Pod::Spec.new do |s|
    s.name             = 'TUIChatKit_Swift'
    s.version          = '9.1.7821'
    s.summary          = 'AtomicX Chat Component'
    s.description      = 'Chat streaming component for AtomicX'
    s.homepage         = 'https://cloud.tencent.com/document/product/269'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Tencent Cloud' => 'im@tencent.com' }
    s.source           = { :git => 'https://github.com/your-repo/atomic-x-chat.git', :tag => s.version.to_s }
    s.ios.deployment_target = '14.0'
    s.swift_version    = '5.0'

    s.dependency 'Kingfisher'
    s.dependency 'AtomicXCore', '>= 3.0.0', '< 5.0'
    s.dependency 'Masonry'
    s.dependency 'AlbumPicker', '~> 1.0.0'

    s.source_files = '*.{swift,h,m}', 'page/**/*.{swift,h,m}', 'components/**/*.{swift,h,m}'

    s.resource_bundles = {
        'ChatUIKitBundle' => [
            'resources/assets/chat/chat.xcassets',
            'resources/strings/**/*.bundle',
        ]
    }

end
