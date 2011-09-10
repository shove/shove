require "yuicompressor"
require "jasmine"



task :default => [:build]

task :build do
  system "coffee -o tmp --compile src/websocket.coffee src/*.coffee"
end

task :deploy do

  puts "Compiling and compressing javascripts..."
  
  unless Dir.exists?("target")
    Dir.mkdir("target")
  end
  
  target = "target/shove.js"
  target_compressed = "target/shove.min.js"
  
  system "coffee --join #{target} --compile src/websocket.coffee  src/*.coffee"
  
  js = File.open(target).read
  json2 = File.open("lib/json2.js").read
  
  # minified for production only!
  js.gsub! "static-dev.shove.io:8888/lib", "static.shove.io"
  js.gsub! "api-dev.shove.io:4000", "api.shove.io"
    
  jsc = YUICompressor.compress_js(js, :munge => true)

  puts "~#{((jsc.length.to_f / js.length.to_f) * 100).round}% compression ratio achieved."
  
  File.open(target_compressed, "w") do |f|
    f.write File.open("lib/swfobject.js").read
    f.write "\n"
    f.write YUICompressor.compress_js(json2, :munge => true)
    f.write "\n"
    f.write "//Copyright 2011 Dan Simpson under the MIT License <http://www.opensource.org/licenses/mit-license.php>\n"
    f.write jsc
  end
  
end

load "jasmine/tasks/jasmine.rake"
