gemspec = eval(File.read(Dir["*.gemspec"].first))

begin
	require 'bundler'
	Bundler.setup
rescue LoadError => er
	$stderr.puts "You need to have Bundler installed to be able to build this gem."
#	Process.exit
end

# This is hacky, but I'm too lazy right now to compare all executables in the $PATH
# and try to work out which gem* command is appropriate.
if $0 =~ /\brake((?:\d+[.\d]))$/
	$version = $1
else
	$version = case RUBY_VERSION
		when /^(1\.\d)\.0$/ then $1
		when /^1\.8\./      then '1.8'
		else RUBY_VERSION
		end
end

desc "Validate the gemspec"
task :gemspec do
	gemspec.validate
end

desc "Build gem locally"
task :build => :gemspec do
	system "gem#$version build #{gemspec.name}.gemspec"
	FileUtils.mkdir_p "pkg-#$version"
	FileUtils.mv "#{gemspec.name}-#{gemspec.version}.gem", "pkg-#$version"
end

desc "Install gem locally"
task :install => :build do
	system "gem#$version install pkg-#$version/#{gemspec.name}-#{gemspec.version}"
end

desc "Publish gem"
task :push => :build do
	system "gem#$version push pkg-#$version/#{gemspec.name}-#{gemspec.version}"
end


desc "Generate rdoc documentation"
task :rdoc do
	system "rdoc#$version #{gemspec.rdoc_options.map{|o| o =~ /\s/ ? '"'+o+'"' : o}.join(' ')}"
end


desc "Clean automatically generated files"
task :clean do
	FileUtils.rm_rf "pkg-#$version"
end
