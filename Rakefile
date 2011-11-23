require "yuicompressor"
require "jasmine"

def files
  [
    "src/log.coffee",
    "src/websocket.coffee",
    "src/transport.coffee",
    "src/channel.coffee",
    "src/shove.coffee"
  ].join(" ")
end

def run cmd
  puts cmd
  system cmd
end

task :default => [:build]

task :build do
  run "coffee -o tmp --compile #{files}"
end

task :deploy do

  puts "Compiling and compressing javascripts..."
  
  unless Dir.exists?("target")
    Dir.mkdir("target")
  end
  
  target = "target/shove.js"
  target_compressed = "target/shove.min.js"
  
  run "coffee --join #{target} --compile #{files}"
  
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

  system "cp lib/proxy.swf ~/shove/shove/app/config/static"
  system "cp target/*.js ~/shove/shove/app/config/static"
  system "cp target/*.js ~/shove/shove/app/target/shove-distribution/shove/config/static"
  
end

load "jasmine/tasks/jasmine.rake"
