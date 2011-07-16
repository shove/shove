require "yuicompressor"

task :default => [:build]

task :build do
  system "coffee -o tmp --compile src/*.coffee"
end

task :deploy do

  target = "lib/shove.js"
  target_compressed = "lib/shove.min.js"
  
  system "coffee --join #{target} --compile src/*.coffee"
  
  
  js = File.open(target).read
  jsc = YUICompressor.compress_js(js, :munge => true)
  puts "~#{((jsc.length.to_f / js.length.to_f) * 100).round}% compression ratio achieved."
  
  File.open(target_compressed, "w") do |f|
    f.write "/*	Copyright 2011 Dan Simpson under the MIT License <http://www.opensource.org/licenses/mit-license.php> */\n"
    f.write jsc
  end
  
end

begin
  require 'jasmine'
  load 'jasmine/tasks/jasmine.rake'
rescue LoadError
  task :jasmine do
    abort "Jasmine is not available. In order to run jasmine, you must: (sudo) gem install jasmine"
  end
end

