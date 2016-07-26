
Pod::Spec.new do |s|

  s.name         = "LFLiveKit"
  s.version      = "1.9.0"
  s.summary      = "LaiFeng ios Live. LFLiveKit."
  s.homepage     = "https://github.com/chenliming777"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "chenliming" => "chenliming777@qq.com" }
  s.platform     = :ios, "7.0"
  s.ios.deployment_target = "7.0"
  s.source       = { :git => "https://github.com/LaiFengiOS/LFLiveKit.git", :tag => "#{s.version}" }
  s.source_files  = "LFLiveKit/**/*.{h,m,mm,cpp}"
  s.public_header_files = "LFLiveKit/**/*.h"

  s.frameworks = "VideoToolbox", "AudioToolbox","AVFoundation","Foundation","UIKit"
  s.libraries = "c++", "z"

  s.requires_arc = true

  s.dependency 'LMGPUImage', '~> 0.1.9'
  s.dependency "YYDispatchQueuePool"
  s.dependency "pili-librtmp", '1.0.3'
end
