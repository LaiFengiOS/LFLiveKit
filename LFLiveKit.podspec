
Pod::Spec.new do |s|

  s.name         = "LFLiveKit"
  s.version      = "2.2.2"
  s.summary      = "LaiFeng ios Live. LFLiveKit."
  s.homepage     = "https://github.com/chenliming777"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "chenliming" => "chenliming777@qq.com" }
  s.platform     = :ios, "7.0"
  s.ios.deployment_target = "7.0"
  s.source       = { :git => "https://github.com/LaiFengiOS/LFLiveKit.git", :tag => "#{s.version}" }
  s.source_files  = "LFLiveKit/**/*.{h,m,mm,cpp,c}"
  #s.public_header_files = "LFLiveKit/LFLiveKit/**/*.h"
  s.public_header_files = ['LFLiveKit/LFLiveKit/*.h', 'LFLiveKit/LFLiveKit/objects/*.h', 'LFLiveKit/LFLiveKit/configuration/*.h']

  s.frameworks = "VideoToolbox", "AudioToolbox","AVFoundation","Foundation","UIKit"
  s.libraries = "c++", "z"

  s.requires_arc = true
  s.ios.vendored_frameworks = 'Vendor/GPUImage.framework','Vendor/pili_rtmp.framework'

end
