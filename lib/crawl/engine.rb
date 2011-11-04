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

  Result = Struct.new(:url, :object)

  attr_reader :options, :errors


  def initialize(caller_options = {})
    @options = DEFAULT_OPTIONS.merge(caller_options)
    @authorization = Base64.encode64("#{options[:username]}:#{options[:password]}")

    @found_links = options[:start].to_set
    @link_sources = {}
    @found_links.each {|target| @link_sources[target] = 'Initial'}
    @visited_links = Set[]
    @visited_documents = Set[]
    @invalid_links = Set[]
    @broken_pages = []
    @errors = []
    @verbose = options[:verbose] || ENV['VERBOSE']
    @number_of_dots = 0
    @report_manager = CI::Reporter::ReportManager.new("crawler") if options[:ci]
  end

  def run
    until (links = @found_links - (@visited_links + @invalid_links)).empty? do
      links.each do |link|
        puts "\nChecking #{link}" if @verbose
        next unless response = retrieve(link)
        next unless response.headers[:content_type] =~ %r{text/html}
        @visited_documents << link
        @found_links += links = find_links(link, response.to_str)
        # validate(link, response.body_str)
      end
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

Pages crawled: #{@visited_documents.size}
Pages with errors: #{@errors.size - @invalid_links.size}
Broken pages: #{@broken_pages.size}
Invalid links: #{@invalid_links.size}

I=Invalid P=Parse Error S=Status code bad

SUM
      exit(@errors.size)
    else
       puts "\n\n#{@visited_documents.size} pages crawled"
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
      handle_success
      true
    else
      response = error_messages.map do |message|
        type, message = message['type'], message['message']
        type_color = type == 'error' ? 31 : 33
        "\e[#{type_color};1m" + type.capitalize + "\e[0m: " + message
      end.join("\n\n")

      @errors << Result.new(link, response)
      handle_error('I')
      false
    end
  rescue RestClient::ServiceUnavailable
    handle_error('U')
    false
  end

  def retrieve(link)
    test_suite = CI::Reporter::TestSuite.new(link)
    test_case  = CI::Reporter::TestCase.new(link)
    test_suite.start
    test_case.start
    puts "  Fetching.." if @verbose

    headers = {}
    #headers.merge!(Authorization: "Basic #{@authorization}") if options[:username]
    headers.merge(user: options[:username], password: options[:password])
    response = RestClient.get(options[:domain] + link, headers)
    test_suite.name = link
    test_case.name = link
    test_case.finish
    @visited_links << link
    unless VALID_RESPONSE_CODES.include?(response.code)
      @errors << Result.new(link, "Status code was #{response.code}")
      @broken_pages << link
      test_case.failures << Crawl::Failure.new(link, response.code, linked_from(link))
      test_suite.testcases << test_case
      test_suite.finish
      @report_manager.write_report(test_suite) if options[:ci]
      return nil
    end
    test_suite.testcases << test_case
    test_suite.finish
    @report_manager.write_report(test_suite) if options[:ci]
    return response
  rescue RestClient::InternalServerError => e
    @errors << Result.new(link, "Error whilst retrieving page: #{e.message}")
    @invalid_links << link
    return nil
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
      unless @found_links.include?(target_link)
        puts "    Adding #{target_link} found on #{source_link}" if @verbose
        @link_sources[target_link] = source_link
      end
    end

    raw_links
  end
end