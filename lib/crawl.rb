# encoding: utf-8
require('nokogiri')
require('rest_client')
# require 'ci/reporter/core'
require 'eventmachine'
require 'em-http-request'
require 'base64'
require 'set'
require 'fileutils'
require 'digest/sha1'
require 'json'
require 'tempfile'
require 'tmpdir'

require_relative "crawl/version"
require_relative "crawl/file_storage"
require_relative "crawl/engine"
require_relative "crawl/string"
require_relative "crawl/failure"
require_relative "crawl/register"
require_relative "crawl/page"

class Crawl
  DEFAULT_OPTIONS = { :domain => '',
                      :start => ['/'],
                      :username => '',
                      :password => '',
                      :verbose => false,
                      :session_id => false,
                      :keep_html => false
                    }

  def initialize(options = {})
    if options[:compare_to]
      puts "#{options[:compare_to]}"
      options[:keep_html] ||= Dir.tmpdir
    end
    @options = DEFAULT_OPTIONS.merge(options)
    @engine = Crawl::Engine.new(comparison_engine, @options)
  end

  def summarize
    engine.summarize
    comparison_engine.summarize if comparison_engine
  end

  def run
    engine.run
  end

  def errors?
    engine.errors?
  end

  def no_links_found?
    engine.no_links_found?
  end

private

  def engine
    @engine
  end

  def comparison_engine
    if @options[:compare_to]
      @comparison_engine ||= Crawl::Engine.new(nil, @options.merge(:domain => @options[:compare_to]))
    end
  end
end
