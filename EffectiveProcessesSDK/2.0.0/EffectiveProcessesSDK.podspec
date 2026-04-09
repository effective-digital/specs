Pod::Spec.new do |s|
  s.name                  = 'EffectiveProcessesSDK'
  s.version               = '2.0.0'
  s.summary               = 'EffectiveProcessesSDK'
  s.license               = 'Proprietary'
  s.homepage              = 'https://effective-digital.com'
  s.author                = { 'Effective Digital' => 'info@effective-digital.com' }
  s.ios.deployment_target = '15.0'
  s.source                = { :http => "https://github.com/effective-digital/ed-sdk-ios/releases/download/2.0.0/EffectiveProcessesSDK.xcframework.zip" }
  s.vendored_frameworks   = 'EffectiveProcessesSDK.xcframework'
end
