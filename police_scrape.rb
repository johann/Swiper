require 'rubygems'
require 'nokogiri'
require 'open-uri'

url = "http://www.policeone.com/law-enforcement-directory/New-York-Agencies/"
doc = Nokogiri::HTML(open(url))

puts doc.at_css("title").text
doc.css(".left").each do |item|
	puts item.css(".left a").text
end