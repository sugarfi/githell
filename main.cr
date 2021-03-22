require "http/client"
require "json"
require "digest/md5"
require "digest/sha1"
require "base64"
require "kemal"
require "dotenv"

Dotenv.load

DEST_REPO = "git-hell/githell"
KEY = ENV["SECRET_KEY"]

class Githell::File
    include JSON::Serializable

    property type : String
    property path : String
    property url : String
    property sha : String

    def initialize(@type : String, @path : String, @name : String, @url : String, @sha : String)
    end
end

class Githell::Contents
    include JSON::Serializable

    property download_url : String

    def initialize(@download_url : String)
    end
end

def get_contents(path : String, repo : String)
    url = "https://api.github.com/repos/#{repo}/contents/#{path}"
    puts "GET #{url}"
    resp = 
        HTTP::Client.get url, 
        headers: HTTP::Headers{ 
            "Accept" => "application/vnd.github.v3+json",
            "Authorization" => "token #{KEY}"
        }

    Array(Githell::File).from_json resp.body
end

def get_file(path : String, repo : String)
    url = "https://api.github.com/repos/#{repo}/contents/#{path}"
    puts "GET #{url}"
    resp = 
        HTTP::Client.get url, 
        headers: HTTP::Headers{ 
            "Accept" => "application/vnd.github.v3+json",
            "Authorization" => "token #{KEY}"
        }

    Githell::File.from_json resp.body
end

def file_exists(path : String)
    url = "https://api.github.com/repos/#{DEST_REPO}/contents/#{path}"
    puts "GET #{url}"
    resp = 
        HTTP::Client.get url, 
        headers: HTTP::Headers{ 
            "Accept" => "application/vnd.github.v3+json",
            "Authorization" => "token #{KEY}"
        }

    resp.status_code == 200
end

def write(path : String, data : String, sha : String)
    body = { "message" => "a", "content" => Base64.encode(data), "sha" => sha }.to_json
    url = "https://api.github.com/repos/#{DEST_REPO}/contents/#{path}"
    puts "PUT #{url}"
    resp = 
        HTTP::Client.put url, 
        headers: HTTP::Headers{ 
            "Accept" => "application/vnd.github.v3+json",
            "Authorization" => "token #{KEY}"
        },
        body: body
    if resp.status_code == 200
        puts "Ok"
    else
        puts "Error: #{resp.status_code}"
    end
end

def write(files : Array(Githell::File), repo : String)
    files.each do |file|
        if file.type == "file"
            puts "Write #{file.path}"
            hash = file.path.split("/").map { |x| Digest::MD5.hexdigest(x) }.join "/"
            puts "Path: #{hash}"
            download_req = 
            HTTP::Client.get file.url,
                headers: HTTP::Headers{ 
                    "Accept" => "application/vnd.github.v3+json",
                    "Authorization" => "token #{KEY}"
                }
            download = Githell::Contents.from_json(download_req.body).download_url
            data = HTTP::Client.get(download).body
            if file_exists hash
                sha = get_file(hash, DEST_REPO).sha
            else
                sha = ""
            end
            write hash, data, sha 
        elsif file.type == "dir"
            write get_contents(file.path, repo), repo
        end
    end
end

get "/" do |env|
    send_file env, "index.html"
end

post "/repo" do |env|
    repo = env.params.body["repo"]
    if repo.match /^.+?\/.+?$/
        spawn do
            write get_contents("", repo), repo 
        end
    end
    env.redirect "/"
end

Kemal.run
