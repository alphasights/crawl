# encoding: utf-8

class Crawl::Engine
  DEFAULT_OPTIONS = {:domain => '',
                     :start => ['/'],
                     :username => '',
                     :password => '',
                     :verbose => false,
                     :session_id => false}


  IGNORE = [/#/, /mailto:/, /skype:/, /logout/, /javascript:/, %r(/xhr/), /https:/, /\.pdf$/, /^$/, /tel:/]
  VALID_RESPONSE_CODES = [200, 302]
  MAX_REDIRECTS = 3
  LINE_WIDTH = 78

  attr_reader :options

  def initialize(caller_options = {})
    @options = DEFAULT_OPTIONS.merge(caller_options)
    @authorization = Base64.encode64("#{options[:username]}:#{options[:password]}")
    @register = Crawl::Register.new

    start_pages = options[:start].to_a.map{|page| Page.new(@register, page, '/')}

    @register.add(start_pages)
  end

  def run
    EventMachine.run do
      process_next
    end
  end

  def process_next
    return if @register.processing_size >= EM.threadpool_size
    if @register.finished?
      EventMachine.stop
    elsif (page = @register.next_page)
      retrieve(page)
      process_next
    end
  end

  def summarize
    @register.summarize
  end

  def errors?
    @register.errors?
  end

  def no_links_found?
    @register.no_links_found?
  end

private

  def retrieve(page)
    puts "Fetching #{page.url} ..." if $verbose

    absolute_url = options[:domain] + page.relative_url

    http = EventMachine::HttpRequest.new(absolute_url)
    req = http.get :redirects => MAX_REDIRECTS,
                   :connect_timeout => 20,
                   :inactivity_timeout => 20
                   :head => {
                     'authorization' => [
                       options[:username], options[:password]
                      ]
                    }
    req.errback do
      if req.nil?
        page.intermittent("Req is nil. WAT?")
      elsif msg = req.error
        page.intermittent(msg)
      elsif req.response.nil? || req.response.empty?
        page.intermittent('Timeout?')
      else
        page.intermittent('Partial response: Server Broke Connection?')
      end
      process_next
    end

    req.callback do
      status_code = req.response_header.status
      if VALID_RESPONSE_CODES.include?(status_code)
        page.success
        if req.response_header["CONTENT_TYPE"] =~ %r{text/html}
          @register.add find_linked_pages(page, req.response.to_str)
        end
      elsif(status_code == 503)
        page.intermittent("Status code: 503")
      else
        page.fatal("Status code: #{status_code}")
      end
      process_next
    end
  end

  def find_linked_pages(page, body)
    doc = Nokogiri::HTML(body)
    anchors = doc.css('a').to_a
    anchors.reject!{|anchor| anchor['onclick'].to_s =~ /f.method = 'POST'/}
    anchors.reject!{|anchor| anchor['data-method'] =~ /put|post|delete/ }
    anchors.reject!{|anchor| anchor['data-remote'] =~ /true/ }
    anchors.reject!{|anchor| anchor['class'].to_s =~ /unobtrusive_/}
    anchors.reject!{|anchor| anchor['rel'].to_s =~ /nofollow/}
    raw_links = anchors.map{|anchor| anchor['href']}
    raw_links.compact!
    raw_links.map!{|link| link.sub(options[:domain], '')}
    raw_links.delete_if{|link| link =~ %r{^http(s)?://} && !link.include?(options[:domain])}
    raw_links.delete_if{|link| IGNORE.any?{|pattern| link =~ pattern}}
    raw_links.map{ |url| Page.new(@register, url, page.url) }
  end
end
