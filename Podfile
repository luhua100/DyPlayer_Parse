platform :ios, '13.0'

target 'MVVM_Local' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for MVVM_Local
  pod 'Alamofire'
  pod 'ObjectMapper'
  pod 'HandyJSON'
  pod 'SnapKit'

end

# Xcode 16 起不再提供 libarclite，HandyJSON 默认的 iOS 8 部署目标会链接失败。
# 统一把 Pod 的最低版本提升到 iOS 13，与本工程使用的 Combine 保持一致。
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
