#!/bin/ruby

require 'rubygems'
require 'hpricot'
require 'net/http'
require 'active_record'
require 'active_support'
require 'cgi'

module NameFactory

	def name_factory(name)

		name.chomp!

		object = find_by_name(name)

		if !object
			object = new
			object.name = name
			object.save
		end

		object

	end

end

class Artist < ActiveRecord::Base

	has_and_belongs_to_many :genres
	has_and_belongs_to_many :styles

	class << self
		include NameFactory
	end

end

class Genre < ActiveRecord::Base

	has_and_belongs_to_many :artists

	class << self
		include NameFactory
	end

end

class Style < ActiveRecord::Base

	has_and_belongs_to_many :artists

	class << self
		include NameFactory
	end

end

class AllMusicGuide

	def initialize
		@http = Net::HTTP.new('www.allmusic.com', 80)
	end

	def get_artist(name)
		search(name)
	end

	protected

		def search(name)

			post = {
				'p' => 'amg',
				'srch_db' => 'pop',
				'srch_type' => 'pop_artist',
				'stype' => '101',
				'srvsrch1' => name
			}

			body = post.map {|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')

			headers = {
				'Referer' => 'http://www.allmusic.com/cg/amg.dll?p=amg&sql=32:amg/info_pages/adv_srch.html',
				'Content-Type' => 'application/x-www-form-urlencoded'
			}

			resp, data = @http.post('/cg/amg.dll', body, headers)

			if data !~ /AMG Artist ID/
				doc = Hpricot(data)
				artist = doc.search('tr.visible td:nth-child(2) a').first
				url = artist.get_attribute('href').to_s
				resp, data = @http.get(url)
			end

			parse_artist(data)

		end

		def parse_artist(data)

			puts data

			doc = Hpricot(data)

			genres = []
			styles = []

			i = 0
			for div in doc.search('div#left-sidebar-list') do

				i += 1

				if i == 1...2
					for a in div.search('ul li a')
						genres << a.inner_html
					end
				elsif i == 3
					for a in div.search('ul li a')
						styles << a.inner_html
					end
				end

			end

			[genres.sort.uniq, styles.sort.uniq]

		end

end

ActiveRecord::Base.establish_connection(
	:adapter  => "mysql",
	:host     => "localhost",
	:username => "seven_steve",
	:password => "cheese",
	:database => "seven_steve"
)

amg = AllMusicGuide.new

artists = File.open('artists.csv', 'r').readlines.collect do |l|
	l = 'The ' + l[0, l.length - 5] if l =~ /, The/
	l
end.sort.uniq

artists = ['311']

for artist_name in artists

	artist = Artist.name_factory(artist_name)

	artist.genres.clear
	artist.styles.clear

	genres, styles = amg.get_artist(artist.name)

	for g in genres
		genre = Genre.name_factory(g)
		artist.genres << genre
	end

	for s in styles
		style = Style.name_factory(s)
		artist.styles << style
	end

	artist.save

	puts "#{artist.name}\t#{artist.genres.count}\t#{artist.styles.count}"

end
