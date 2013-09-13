require 'spec_helper'

describe Crawl::FileStorage::UriToPath do
  describe "#convert" do
    it "stores http://some.example.com/ under /tmp/some_example_com/index.html" do
      uri = Addressable::URI.parse("http://some.example.com/")
      converter = Crawl::FileStorage::UriToPath.new(uri, "/tmp")
      expect(converter.convert).to eq "/tmp/some_example_com/index.html"
    end

    it "adds .html to for urls that don't have it" do
      uri = Addressable::URI.parse("http://some.example.com/main/page")
      converter = Crawl::FileStorage::UriToPath.new(uri, "/tmp")
      expect(converter.convert).to eq "/tmp/some_example_com/main/page.html"
    end
  end
end
