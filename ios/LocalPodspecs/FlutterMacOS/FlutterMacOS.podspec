# Local stub so darwin Flutter plugins resolve when CocoaPods CDN is unreachable.
Pod::Spec.new do |s|
  s.name             = 'FlutterMacOS'
  s.version          = '3.16.0'
  s.summary          = 'Local stub for iOS CocoaPods resolution'
  s.description      = 'Satisfies FlutterMacOS dependency from darwin plugins during iOS builds.'
  s.homepage         = 'https://flutter.dev'
  s.license          = { :type => 'BSD' }
  s.author           = { 'Flutter Dev Team' => 'flutter-dev@googlegroups.com' }
  s.source           = { :path => '.' }
  s.ios.deployment_target = '14.0'
  s.osx.deployment_target = '10.14'
  s.source_files     = 'stub/FlutterMacOSStub.m'
end
