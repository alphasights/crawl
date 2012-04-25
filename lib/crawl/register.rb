class Crawl::Register
  def initialize(unprocessed)
    @unprocessed = unprocessed
    @processing = []
    @processed = []
  end
  
  def add(links)
    new_links = links - @processed - @processing - @unprocessed
    @unprocessed += new_links
  end
  
  def next_link
    link = @unprocessed.shift
    @processing << link if link
    link
  end
  
  def returned(link)
    @processed << link
    @processing -= [link]
  end
  
  def finished?
    @unprocessed.size + @processing.size == 0
  end
  
  def processed_size
    @processed.size
  end
  
  def retry(link, reason)
    puts "Retrying #{link} : #{reason}"
    @processing -= [link]
    @unprocessed << link
  end
end