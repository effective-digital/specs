
  Pod::Spec.new do |s|
    s.name = 'EffectiveProcessesSDK'
    s.ios.deployment_target = '15.0'
    s.version = '1.0.29'
    s.source = { :git => "git@github.com:effective-digital/ed-sdk-ios.git", :tag => s.version }
    s.author = { "Jasmin Ceco" => "jasmin.ceco@gmail.com" }
    s.license = 'Proprietary'
    s.homepage = 'https://efectivedigital.com'
    s.summary = 'EffectiveProcessesSDK'
     # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    s.vendored_frameworks = 'EffectiveProcessesSDK.xcframework'
    s.dependency  'IQKeyboardManagerSwift', '6.5.16'
    s.dependency  'Kingfisher'
    s.dependency  'JWTDecode'
    s.dependency  'Resolver', '1.2.1'
    s.dependency  'lottie-ios'
    s.dependency  'RxSwift'
    s.dependency  'RxCocoa'
    s.dependency  'SwiftUIIntrospect', '~> 1.0'
  end
