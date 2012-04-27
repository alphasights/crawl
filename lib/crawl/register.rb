class Crawl::Register

  Result = Struct.new(:url, :object)

  def initialize(unprocessed)
    @unprocessed = unprocessed
    @processing = []
    @processed = []

    @invalid_links = Set[]
    @broken_pages = Set[]

    @errors = []
    @link_sources = {}
  end

  def add(links)
    new_links = links - @processed - @processing - @unprocessed
    @unprocessed += new_links
  end

  def next_link
    link = @unprocessed.shift
    @processing << link if link
    if @processing.size > EM.threadpool_size
      puts "WARNING: #{@processing.size} pages are being process when EM threadpool only has #{EM.threadpool_size} threads."
    end
    link
  end

  def set_link_source(link, source)
    @link_sources[link] = source
  end

  def source_for(link)
    @link_sources.fetch link, '?'
  end

  def error(link, object)
    @errors << Result.new(link, object)
  end

  def returned_invalid(link)
    returned link
    @invalid_links << link
  end

  def returned_broken(link)
    returned link
    @broken_pages << link
  end

  def returned(link)
    @processed << link
    @processing -= [link]
  end

  def finished?
    @unprocessed.size + @processing.size == 0
  end

  def processing_size
    @processing.size
  end

  def retry(link, reason)
    puts "Retrying #{link} : #{reason}"
    @processing -= [link]
    @unprocessed << link
  end

  def summarize
    if @errors.size > 0

      @errors.each do |error|
        puts "\n#{error.url}"
        puts "  Linked from #{source_for error.url}"
        puts error.object.to_s.word_wrap.split("\n").map{|line| '  ' + line}
      end

      print(<<-SUM)

Pages crawled: #{@processed.size}
Pages with errors: #{@errors.size - @invalid_links.size}
Broken pages: #{@broken_pages.size}
Invalid links: #{@invalid_links.size}

I=Invalid P=Parse Error S=Status code bad

SUM
      exit(@errors.size)
    else
       puts "\n\n#{@processed.size} pages crawled"
    end

    puts
  end

  def errors?
    @errors.size > 0
  end
end