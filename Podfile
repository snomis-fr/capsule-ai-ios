# CapsuleAI — OAuth via Supabase (flux navigateur, pas de nonce)
platform :ios, '17.0'
use_frameworks!

project 'CapsuleAI.xcodeproj'

target 'CapsuleAI' do
  # Google Sign-In gardé pour compatibilité build (non utilisé — OAuth Supabase)
  pod 'GoogleSignIn', '~> 7.0'
end

post_install do |installer|
  # Niveau projet Pods
  installer.pods_project.build_configurations.each do |config|
    config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
  end
  # Niveau cibles (AppAuth, GTMSessionFetcher, GTMAppAuth, GoogleSignIn)
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
    end
  end
end
