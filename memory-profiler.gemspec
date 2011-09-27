require 'rubygems'
require 'rubygems/user_interaction' if RUBY_VERSION >= '1.9.1' and Gem::VERSION >= '1.4'
require 'rake'

Gem::Specification.new do |s|
	s.name              = 'memory-profiler'
	s.version           = '1.0.2'
	s.platform          = Gem::Platform::RUBY
	s.authors           = ['Matthew Kerwin']
	s.email             = ['matthew@kerwin.net.au']
	s.homepage          = 'http://code.google.com/p/memory-profiler-ruby/'
	s.summary           = 'A Ruby Memory Profiler'
	s.description       = 'A rudimentary memory profiler that uses pure in-VM techniques to analyse the object space and attempt to determine memory usage trends.'
	s.license           = 'Apache License 2.0'
	s.rubyforge_project = 'mem-prof-ruby'

	s.required_rubygems_version = '>= 1.3.6'

	s.files            = Rake::FileList['lib/**/*.rb', '[A-Z]*'].to_a
	s.require_path     = 'lib'

	s.has_rdoc         = true
	s.rdoc_options << '--title' << 'Memory Profiler' <<
	                  '--main' << 'MemoryProfiler' <<
	                  '--line-numbers' <<
	                  '--tab-width' << '2'
end
