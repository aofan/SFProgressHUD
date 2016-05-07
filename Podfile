# Uncomment this line to define a global platform for your project
platform :ios, '8.0'
use_frameworks!

# ignore all warnings from all pods
inhibit_all_warnings!

target 'ProgressHUD' do

  pod 'SnapKit', '~> 0.15.0'
end


post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
