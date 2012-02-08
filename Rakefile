require "rubygems"
require "yuicompressor"
require "jasmine"
require "yaml"
require "right_aws"

# S3 bucket
BUCKET = "shove-cdn"

# Config
VERSION = "0.8"

# Files to compile
FILES = [
  "src/transport.coffee",
  "src/channel.coffee",
  "src/shove.coffee",
  "src/mock_socket.coffee"
].join(" ")

# Where we write compiled files
OUT_DIR = File.dirname(__FILE__) + "/build"

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
    Log.info  "Invalidated #{files.join(", ")}"
  end
end


task :default => [:build]

desc "Compile coffeescript to js"
task :compile do
  system "coffee -o tmp --compile #{FILES}"
end

desc "Publish dev to S3"
task :publish_dev do

  Log.info "Compiling to javascript..."
  
  unless Dir.exists?(OUT_DIR)
    Dir.mkdir(OUT_DIR)
  end
  
  target = "#{OUT_DIR}/shove.js"
  system "coffee --join #{target} --compile #{FILES}"
  
  Log.info "Combining..."
  
  content = ""
  ["lib/swfobject.min.js", "lib/json2.min.js"].each do |src|
    content << File.open(src).read
    content << "\n"
  end
  content << File.open(target).read
  
  Log.info "Deploying to #{BUCKET}..."

  headers = {
    "Content-Type" => "text/javascript"
  }

  publish("shove.dev.js", content, headers)

  invalidate(["/shove.dev.js"])

end

desc "Build the js file for production"
task :build do

  Log.info "Compiling to javascript..."
  
  unless Dir.exists?(OUT_DIR)
    Dir.mkdir(OUT_DIR)
  end
  
  target = "#{OUT_DIR}/shove.js"
  target_compressed = "#{OUT_DIR}/shove.min.js"
  
  system "coffee --join #{target} --compile #{FILES}"
  
  Log.info "Compressing..."

  # Clean up the links
  js = File.open(target).read
  js.gsub! "localhost:8888/lib", "cdn.shove.io"
  js.gsub! "shove.dev:8000", "api.shove.io"   
  js = YUICompressor.compress_js(js, :munge => true)

  Log.info "Combining..."
  
  File.open(target_compressed, "w") do |f|
    ["lib/swfobject.min.js", "lib/json2.min.js", "lib/websocket.js"].each do |src|
      f << File.open(src).read
      f << "\n"
    end
    f << "//Shove v#{VERSION} Copyright 2011 Shove under the MIT License <http://www.opensource.org/licenses/mit-license.php>\n"
    f << js
  end

end

desc "Autocompile"
task :autobuild do
  Log.info "Watching coffee..."
  
  unless Dir.exists?(OUT_DIR)
    Dir.mkdir(OUT_DIR)
  end
  
  target = "#{OUT_DIR}/shove.js"
  
  loop do
    system "coffee --join #{target} --compile #{FILES}"
    sleep 1
  end
end

desc "Publish the result javascript code to S3 and invalidate CF cache"
task :publish => [:build] do

  Log.info "Deploying to #{BUCKET}..."

  content = File.open("#{OUT_DIR}/shove.min.js").read

  headers = {
    "Content-Type" => "text/javascript"
  }

  publish("shove.js", content, headers)
  publish("shove-#{VERSION}.js", content, headers)

  invalidate(["/shove.js", "/shove-#{VERSION}.js"])

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
