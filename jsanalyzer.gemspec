require_relative 'lib/js_analyzer/version'

Gem::Specification.new do |s|
  s.name          = 'js_analyzer'
  s.version       = JSAnalyzer::VERSION
  s.authors       = ["Jon Bracy"]
  s.email         = ["jonbracy@gmail.com"]
  s.homepage      = "https://github.com/malomalo/js_analzyer"
  s.summary       = ''
  s.description   = ""
  s.license       = "MIT"

  s.extra_rdoc_files = %w(README.md)
  s.rdoc_options.concat ['--main', 'README.md']

  s.files         = `git ls-files -- README.md CHANGELOG.md LICENSE {lib,ext}/*`.split("\n")
  s.test_files    = `git ls-files -- test/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = %w(lib)
  
  s.required_ruby_version = '>= 3.2.0'

  s.add_runtime_dependency  "stream_parser", '~> 0.5'
  
  s.add_development_dependency "rake"
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-reporters'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'byebug'
end

