require "rubygems"
require "bundler/setup"

Bundler.require

# S3 bucket
BUCKET = "shove-cdn"

# Config
VERSION = File.open("./shove.coffee").read.match(/Version\s*:\s*['"]([.\d]+)['"]/)[1]

# Files to compile
FILES = [
  "shove.coffee"
].join(" ")

# Where we write compiled files
OUT_DIR = File.dirname(__FILE__)

Log = Logger.new(STDOUT)

# Get aws config
def get_config
  config = File.expand_path("~/.shove-aws.yml")

  unless FileTest.exist?(config)

    def getinput text
      print text
      STDIN.gets.strip
    end

    access = {}
    access[:access_key_id] = getinput "Access Key Id: "
    access[:secret_access_key] = getinput "Secret Access Key: "

    File.open(config, "w") do |f|
      f << access.to_yaml
    end
  end

  YAML.load_file(config)
end

# S3 API
def s3
  config = get_config
  @s3 ||= RightAws::S3Interface.new(config[:access_key_id], config[:secret_access_key])
end

# Cloudfront API
def cf
  config = get_config
  @cf ||= RightAws::AcfInterface.new(config[:access_key_id], config[:secret_access_key])
end

# Publish content to S3
def publish name, content, headers
  result = s3.put(BUCKET, name, content, headers)
  if result
    Log.info "Deployed #{name} successful"
  end
end

# Invalidate the Cloudfront cache
def invalidate files
  result = cf.create_invalidation("E8HK41AEIJZNG", :path => files)
  if result
    Log.info "Invalidated #{files.join(", ")}"
  end
end

task :default => :spec

task :spec do
  system "coffee specs/shove_specs.coffee"
end

task :spec_browser do
  system "coffee -b -c -o ./specs/browser/ ./shove.coffee"
  system "coffee -b -c -o ./specs/browser/ ./specs/runner.coffee"
  system "coffee -b -c -o ./specs/browser/ ./specs/shove_specs.coffee"
end

desc "Watch files and run the spec, coffee --watch on many + run"
task :autospec => [:spec] do

  require "eventmachine"
  
  $last = Time.now

  module Handler
    def file_modified
      if Time.now - $last > 1
        $last = Time.now
        system "coffee specs/shove_specs.coffee"
      end
    end
  end

  EM.kqueue if EM.kqueue?
  EM.run do
    EM.watch_file "shove.coffee", Handler
    EM.watch_file "specs/shove_specs.coffee", Handler
    EM.watch_file "specs/runner.coffee", Handler
  end

end

desc "combine libs with shove lib for production"
task :combine do
  Log.info "Combining..."
  
  file_source = "shove.coffee"
  file_js = "shove.js"
  file_combined = "#{OUT_DIR}/shove.dev.js"
  
  unless Dir.exists?(OUT_DIR)
    Dir.mkdir(OUT_DIR)
  end
  
  system "coffee --bare --compile #{file_source}"
  
  combine = "(function(root) {"
  
  [
    "lib/json2.js",
    "lib/swfobject.js",
    "lib/web_socket.js",
    file_js
  ].each do |f|
    combine << File.open(f).read
    combine << "\n\n"
  end
  combine << "})(window);"
  
  combine.gsub! "localhost:8888/lib", "cdn.shove.io"
  combine.gsub! "shove.dev:8000", "api.shove.io"
  combine.gsub! "shove.dev:9000", "api.shove.io"
  
  File.open(file_combined,"w") do |f|
    f << combine
  end

  Log.info "...Combining Done!"
end

desc "compress combined javascript"
task :minify => [:combine] do
  Log.info "Minifying..."
  
  unless Dir.exists?(OUT_DIR)
    Dir.mkdir(OUT_DIR)
  end

  file_combined = "#{OUT_DIR}/shove.dev.js"
  file_minified = "#{OUT_DIR}/shove.min.js"
  file_compressed = "#{OUT_DIR}/shove.min.js.gz"
  
  combine = File.open(file_combined).read

  File.open(file_minified, "w") do |f|
    f << YUICompressor.compress_js(combine, :munge => true)
    f << "\n//Shove v#{VERSION} Copyright 2012 Shove under the MIT License <http://www.opensource.org/licenses/mit-license.php>\n"
  end

  Log.info "Compressing..."

  system "gzip -1 -c #{file_minified} > #{file_compressed}"
  
  Log.info "... Minifying Done!"
end

desc "Publish the result javascript code to S3 and invalidate CF cache"
task :publish => [:minify] do

  Log.info "Deploying to #{BUCKET}..."
  
  files = [
      {
        :local => "#{OUT_DIR}/shove.dev.js",
        :remote => "shove.js",
        :headers => {"Content-Type" => "text/javascript"}
      },
      {
        :local => "#{OUT_DIR}/shove.min.js",
        :remote => "shove.min.js",
        :headers => {"Content-Type" => "text/javascript"}
      }
      # ,
      # {
      #   :local => "#{OUT_DIR}/shove.min.js.gz",
      #   :remote => "shove.min.js.gz",
      #   :headers => {"Content-Type" => "application/x-gzip"}
      # }
    ]
  
  files.each do |f|
    content = File.open(f[:local]).read
    
    publish(f[:remote],content,f[:headers])
    publish("#{VERSION}/#{f[:remote]}",content,f[:headers])
  end

  invalidate(files.collect {|f| "/#{f[:remote]}"} + files.collect {|f| "/#{VERSION}/#{f[:remote]}"})
  
  Log.info "...Deploying to #{BUCKET} Done!"

end

desc "Publish flash fallback to S3 invalidate CF cache"
task :publish_swf do

  Log.info "Deploying flash fallback"

  content = File.open(File.dirname(__FILE__) + "/lib/proxy.swf").read

  publish("proxy.swf", content, {
    "Content-Type" => "application/x-shockwave-flash"
  })

  invalidate(["/proxy.swf"])

end

load "jasmine/tasks/jasmine.rake"
