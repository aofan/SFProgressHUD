Pod::Spec.new do |s|
  s.name         = 'SFProgressHUD'
  s.version      = '0.2.0'
  s.summary      = "Progress, simelpe MBProgress by swift 2.2"
  s.homepage     = 'https://github.com/looseyi/SFProgressHUD.git'
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { 'looseyi' => '13615033587@126.com' }

  s.platform     = :ios, '8.0'
  s.source       = { :git => "https://github.com/looseyi/SFProgressHUD.git", :tag => s.version }
  s.source_files = 'Source/*.swift'
  s.exclude_files = "Classes/Demo"
  s.framework    = "CoreGraphics"
  s.requires_arc = true
  s.dependency "SnapKit", "~> 0.15.0"
end
