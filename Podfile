# Uncomment the next line to define a global platform for your project
platform :ios, '14.4'

target 'VidyoConnector' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for VidyoConnector
  pod 'DevicePpi'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.4'
    end
  end
end
