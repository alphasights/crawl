# encoding: utf-8

require 'eventmachine'
require 'em-http-request'

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

  Result = Struct.new(:url, :object)

  attr_reader :options, :errors


  def initialize(caller_options = {})
    @options = DEFAULT_OPTIONS.merge(caller_options)
    @authorization = Base64.encode64("#{options[:username]}:#{options[:password]}")
    @verbose = options[:verbose] || ENV['VERBOSE']
    @validate_markup = options[:markup]
    @register = Crawl::Register.new(options[:start].to_a)

    @invalid_links = Set[]
    @broken_pages = []
    @errors = []
            
    @link_sources = {}
    # @pending_queue.each {|target| @link_sources[target] = 'Initial'}

    @report_manager = CI::Reporter::ReportManager.new("crawler") if options[:ci]
  end

  def run
    EventMachine.run do
      process_next
    end
  end

  def process_next
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
    if @errors.size > 0

      @errors.each do |error|
        puts "\n#{error.url}"
        puts "  Linked from #{linked_from(error.url)}"
        puts error.object.to_s.word_wrap.split("\n").map{|line| '  ' + line}
      end

      print(<<-SUM)

Pages crawled: #{@register.processed_size}
Pages with errors: #{@errors.size - @invalid_links.size}
Broken pages: #{@broken_pages.size}
Invalid links: #{@invalid_links.size}

I=Invalid P=Parse Error S=Status code bad

SUM
      exit(@errors.size)
    else
       puts "\n\n#{@register.processed_size} pages crawled"
    end

    puts
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

      @errors << Result.new(link, response)
      false
    end
  rescue RestClient::ServiceUnavailable
    handle_error('U')
    false
  end


  def retrieve(link)
    # test_suite = CI::Reporter::TestSuite.new(link)
    # test_case  = CI::Reporter::TestCase.new(link)
    # test_suite.start
    # test_case.start
    # test_suite.name = link
    # test_case.name = link

    # attributes = {:method => :get, :url => options[:domain] + link}
    # attributes.merge!(user: options[:username], password: options[:password])
    # response = RestClient::Request.execute(attributes)

    puts "Fetching #{options[:domain] + link} ..." if @verbose
    
    unless link.start_with? '/'
      @register.returned link
      @errors << Result.new(link, "Relative path found. Crawl does not support relative paths.")
      @invalid_links << link
      return nil
    end
    
    http = EventMachine::HttpRequest.new(options[:domain] + link)
    req = http.get :redirects => MAX_REDIRECTS, :head => {'authorization' => [options[:username], options[:password]]}

    req.errback do
      @register.returned link
      @errors << Result.new(link, "Error whilst retrieving page: TODO MSG")
      @invalid_links << link
    end

    req.callback do
      @register.returned link
      if VALID_RESPONSE_CODES.include?(req.response_header.status)
        if req.response_header["CONTENT_TYPE"] =~ %r{text/html}
          @register.add find_links(link, req.response.to_str)
        end
      else
        @errors << Result.new(link, "Status code was #{req.response_header.status}")
        @broken_pages << link
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
    # return response
  end

  def linked_from(target)
    @link_sources[target] # => source
  end

  def find_links(source_link, body)
    puts "  Finding links.." if @verbose
    doc = Nokogiri::HTML(body)
    anchors = doc.css('a').to_a
    anchors.reject!{|anchor| anchor['onclick'].to_s =~ /f.method = 'POST'/}
    anchors.reject!{|anchor| anchor['data-method'] =~ /put|post|delete/ }
    anchors.reject!{|anchor| anchor['class'].to_s =~ /unobtrusive_/}
    raw_links = anchors.map{|anchor| anchor['href']}
    raw_links.compact!
    raw_links.map!{|link| link.sub(options[:domain], '')}
    raw_links.delete_if{|link| link =~ %r{^http://}}
    raw_links.delete_if{|link| IGNORE.any?{|pattern| link =~ pattern}}
    raw_links.each do |target_link|
      puts "    Adding #{target_link} found on #{source_link}" if @verbose
      @link_sources[target_link] = source_link
    end

    raw_links
  end
end