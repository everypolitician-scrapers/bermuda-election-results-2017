#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'
# require 'scraped_page_archive/open-uri'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

class ResultsPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :results_urls do
    noko.css('table#res-tbl tr a/@href').map(&:text)
  end
end

class ResultPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :name do
    winner.css('.CanDetails span.ucase').text.tidy
  end

  field :image do
    winner.css('.CanPhoto img/@src').map(&:text).last
  end

  private

  def winner
    noko.xpath('//div[contains(@class,"canBox")][.//img[@class="winnerGif"]]')
  end
end

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

start = 'https://elections.gov.bm/elections/results/electionss.html?kid=287'
data = scrape(start => ResultsPage).results_urls.map do |url|
  scrape(url => ResultPage).to_h
end
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[name], data)
