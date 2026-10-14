require_relative 'lib/jsparser/version'

Gem::Specification.new do |s|
  s.name          = 'jsparser'
  s.version       = JSParser::VERSION
  s.authors       = ["Jon Bracy"]
  s.email         = ["jonbracy@gmail.com"]
  s.homepage      = "https://github.com/malomalo/jsparser"
  s.summary       = 'A JavaScript parser in Ruby, with scope analysis'
  s.description   = <<~DESC
    Parses JavaScript into a tree of nodes that prints back as JavaScript,
    keeping comments. Every variable reference is resolved to its
    declaration, so you can list the variables in scope, tell reads from
    writes, and rename a variable everywhere it's used. Output is checked
    against acorn.
  DESC
  s.license       = "MIT"

  s.extra_rdoc_files = %w(README.md)
  s.rdoc_options.concat ['--main', 'README.md']

  s.files         = `git ls-files -- README.md CHANGELOG.md LICENSE {lib,ext}/*`.split("\n")
  s.test_files    = `git ls-files -- test/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = %w(lib)
  
  s.required_ruby_version = '>= 3.4.0'

  
  s.add_development_dependency "rake"
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'minitest', '~> 6.0'
  s.add_development_dependency 'minitest-reporters', '>= 1.8'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'byebug'
end

