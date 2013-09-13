class Crawl::FileStorage
  class UriToPath
    def initialize(uri, root_path)
      @uri       = uri
      @root_path = root_path
    end

    def convert
      File.join(@root_path, site_root, path)
    end

  private
    def site_root
      @uri.host.gsub(".", "_")
    end

    def path
      filepath  = @uri.path.gsub(/\/$/, '').to_s
      filepath  += "index.html" if filepath.empty?
      filepath  += ".html"      unless filepath.match(/\.html$/)
      filepath
    end
  end
end
