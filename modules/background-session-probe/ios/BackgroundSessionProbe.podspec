Pod::Spec.new do |s|
  s.name           = 'BackgroundSessionProbe'
  s.version        = '1.0.0'
  s.summary        = 'Owns a background URLSession to show who answers handleEventsForBackgroundURLSession'
  s.author         = ''
  s.homepage       = 'https://example.com'
  s.platforms      = { :ios => '16.4' }
  s.source         = { git: '' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.source_files = '**/*.swift'
end
