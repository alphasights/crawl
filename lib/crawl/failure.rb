# encoding: utf-8
class Crawl::Failure
  attr_reader :link, :code, :from

  def initialize(link, code, from)
    @link = link
    @code = code
    @from = from
  end

  def failure?
    true
  end

  def error?
    !failure?
  end

  def name
    link
  end

  def message
    "Status code was #{code}"
  end

  def location
    "Linked from #{from}"
  end
end