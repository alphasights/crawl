require './lib/crawl/page'

RSpec.describe Crawl::Page do
  describe "#relative_url" do
    specify { expect(described_class.new(:register, "/", "/").relative_url).to eq "/" }
    specify { expect(described_class.new(:register, "./", "/").relative_url).to eq "/" }
    specify { expect(described_class.new(:register, "page.html", "").relative_url).to eq "/page.html" }
    specify { expect(described_class.new(:register, "/interview", "/").relative_url).to eq "/interview" }
    specify { expect(described_class.new(:register, "overview.html", "/").relative_url).to eq "/overview.html" }
    specify { expect(described_class.new(:register, "post-5.html", "/posts/index.html").relative_url).to eq "/posts/post-5.html" }
    specify { expect(described_class.new(:register, "https://staging.alphasights.com/careers/meet-us", "/posts/foo").relative_url).to eq "/careers/meet-us" }
  end
end
