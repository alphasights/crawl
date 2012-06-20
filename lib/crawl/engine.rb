# encoding: utf-8

class Crawl::Engine
  DEFAULT_OPTIONS = {:domain => '',
                     :start => ['/'],
                     :username => '',
                     :password => '',
                     :verbose => false,
                     :session_id => false}


  IGNORE = [/#/, /mailto:/, /skype:/, /logout/, /javascript:/, %r(/xhr/), /https:/, /\.pdf$/, /^$/]
  VALID_RESPONSE_CODES = [200, 302]
  MAX_REDIRECTS = 3
  LINE_WIDTH = 78

  attr_reader :options

  def initialize(caller_options = {})
    @options = DEFAULT_OPTIONS.merge(caller_options)
    @authorization = Base64.encode64("#{options[:username]}:#{options[:password]}")
    @verbose = options[:verbose] || ENV['VERBOSE']
    @validate_markup = options[:markup]
    @register = Crawl::Register.new(options[:start].to_a, @verbose)

    @report_manager = CI::Reporter::ReportManager.new("crawler") if options[:ci]
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
    elsif (link = @register.next_link)
      puts "\nChecking #{link}" if @verbose
      retrieve(link)
      # validate(link, response.body) if @validate_markup
      process_next
    end
  end

  def summarize
    @register.summarize
  end

  def errors?
    @register.errors?
  end

private

  def validate(link, body)
    puts "  Validating..." if @verbose

    json_response = RestClient.post 'http://validator.nu?out=json', body, :content_type => 'text/html; charset=utf-8'
    messages = JSON.parse(json_response.body)['messages']
    error_messages = messages.select { |message| message['type'] != 'info' }

    if error_messages.empty?
      true
    else
      response = error_messages.map do |message|
        type, message = message['type'], message['message']
        type_color = type == 'error' ? 31 : 33
        "\e[#{type_color};1m" + type.capitalize + "\e[0m: " + message
      end.join("\n\n")

      @register.error link, response
      false
    end
  rescue RestClient::ServiceUnavailable
    handle_error('U')
    false
  end

  def register_error(link, message)
    @register.error link, message
    @register.returned_invalid link
    process_next
  end

  def retrieve(link)
    # test_suite = CI::Reporter::TestSuite.new(link)
    # test_case  = CI::Reporter::TestCase.new(link)
    # test_suite.start
    # test_case.start
    # test_suite.name = link
    # test_case.name = link

    puts "Fetching #{options[:domain] + link} ..." if @verbose

    unless link.start_with? '/'
      register_error(link, "Relative path found. Crawl does not support relative paths.")
      return nil
    end

    http = EventMachine::HttpRequest.new(options[:domain] + link)
    req = http.get :redirects => MAX_REDIRECTS, :head => {'authorization' => [options[:username], options[:password]]}
    req.timeout(30)

    req.errback do
      if req.nil?
         @register.retry(link, 'WAT?')
         process_next
       elsif msg = req.error
         register_error(link, msg)
       elsif req.response.nil? || req.response.empty?
         @register.retry(link, 'Timeout?')
         process_next
         # register_error(link, 'Timeout?')
       else
         @register.retry(link, 'Partial response: Server Broke Connection?')
         process_next
       end
    end

    req.callback do
      if VALID_RESPONSE_CODES.include?(req.response_header.status)
        @register.returned link
        if req.response_header["CONTENT_TYPE"] =~ %r{text/html}
          @register.add find_links(link, req.response.to_str)
        end
      else
        @register.error link, "Status code was #{req.response_header.status}"
        @register.returned_broken link
        # test_case.failures << Crawl::Failure.new(link, req.response_header.status, linked_from(link))
        # test_suite.testcases << test_case
        # test_suite.finish
        # @report_manager.write_report(test_suite) if options[:ci]
      end
      process_next
    end

    # test_case.finish
    # test_suite.testcases << test_case
    # test_suite.finish
    # @report_manager.write_report(test_suite) if options[:ci]
  end

  def linked_from(target)
    @register.source_for target
  end

  def find_links(source_link, body)
    puts "  Finding links.." if @verbose
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
    raw_links.delete_if{|link| link =~ %r{^http(s)?://}}
    raw_links.delete_if{|link| IGNORE.any?{|pattern| link =~ pattern}}
    raw_links.each do |target_link|
      @register.set_link_source(target_link, source_link)
    end

    raw_links
  end
end