require 'spec_helper'

describe Crawl::FileStorage do
  describe "#persist" do
    it "stores two files: one in a new dir, another one in an existing dir" do
      file1_path = File.join(Dir.tmpdir, "a", "x.html")
      file2_path = File.join(Dir.tmpdir, "a", "z.html")

      Crawl::FileStorage.new("hello", file1_path).persist
      Crawl::FileStorage.new("hello", file2_path).persist

      expect(File.read(file1_path)).to eq("hello")
      expect(File.read(file2_path)).to eq("hello")
    end
  end
end
