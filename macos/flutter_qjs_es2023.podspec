#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_qjs_es2023.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_qjs_es2023'
  s.version          = '0.0.1'
  s.summary          = 'A quickjs engine for flutter.'
  s.description      = <<-DESC
This plugin is a simple js engine for flutter using the `quickjs` project. Plugin currently supports all the platforms except web!
                       DESC
  s.homepage         = 'https://github.com/NanCunChild/flutter_qjs_es2023'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'NanCunChild' => 'https://github.com/NanCunChild' }
  s.source           = { :path => '.' }
  s.compiler_flags = '-DDUMP_LEAKS'
  s.source_files = ['Classes/**/*', 'cxx/*.{c,cpp}']
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.vendored_libraries = 'build/Debug/libffiquickjs.dylib'
  s.prepare_command = 'sh ../cxx/prebuild.sh'
  s.swift_version = '5.0'
end
