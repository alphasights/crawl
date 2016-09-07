require 'uri'

class Page
  include Comparable

  attr_reader :register, :url, :source, :error

  ATTEMPTS = 3

  def initialize(register, url, source)
    @register = register
    @url = url
    @source = source
    @attempts = 0
    @errors = nil
  end

  def relative_url
    @relative_url ||= URI.join('http://example.com', source, url).path
  end

  def <=>(other)
    relative_url <=> other.relative_url
  end

  def eql?(other)
    relative_url.eql?(other.relative_url)
  end

  def hash
    relative_url.hash
  end

  def success
    @error = nil
    @register.completed(self)
  end

  def fatal(error)
    puts "  Fatal - #{error}" if $VERBOSE
    @error = error
    @register.completed(self)
  end

  def intermittent(error)
    puts "  Intermittent - #{error}" if $VERBOSE
    if @attempts >= ATTEMPTS
      @error = error
      @register.completed(self)
    else
      @attempts += 1
      @register.retry(self)
    end
  end

  def to_s
    "#{url} found on #{source} - #{error || 'OK'}"
  end
end
