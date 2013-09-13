require 'fileutils'
require_relative 'file_storage/uri_to_path'

class Crawl::FileStorage
  def self.from_request(request, root_system_path)
    uri       = request.req.uri
    full_path = Crawl::FileStorage::UriToPath.new(uri, root_system_path).convert
    new(request.response.to_str, full_path)
  end

  def initialize(content, full_path)
    @content   = content
    @full_path = full_path
  end

  def persist
    FileUtils.mkdir_p(File.dirname(@full_path))
    File.open(@full_path, 'w+'){ |f|
      f.write(@content)
    }
  end
end

