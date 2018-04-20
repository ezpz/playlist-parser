#!/usr/bin/env ruby

require 'csv'
require 'cgi'
require 'nokogiri'
require 'fileutils'

DB = 'database/song.db'
DBBKUP = 'database/song.db.orig'
DBTMP = 'database/song.db.tmp'
SETLIST = 'index.html'

$artists = {} # {name => [proper name, id]}
$songs = [] # [date, artist, title, year, proper_name, id] 
$base_date = nil
$debug = false

def trace msg
    puts msg if $debug
end

def normalize_year year
    year.split('-')[0]
end

def best_album_match release_xml
    year, best_id, score = nil, nil, 0
    release_xml.css("recording-list recording").each do |rec|
        s = rec.attribute('score').text.to_i
        if s > score
            best_id = rec.attribute('id').text
            score = s
        end
    end
    return nil if score == 0
    # Now find details of the best ranked album
    release_xml.css("recording-list recording").each do |rec|
        next unless rec.attribute("id").text == best_id
        year = rec.css('release-list release date')[0].text
        break
    end
    normalize_year year
end

def best_artist_match artist_xml
    name, id, score = nil, nil, 0
    artist_xml.css('artist-list artist').each do |artist|
        unless id
            id = artist.attribute('id').text
            score = artist.attribute('score').text.to_i
            name = artist.css('name')[0].text
        else
            s = artist.attribute('score').text.to_i
            if s > score
                id = artist.attribute('id').text
                score = s
                name = artist.css('name')[0].text
            end
        end
    end
    return [nil, nil, nil] if score < 50
    [name, id, score]
end

def query_date xml
    $base_date = xml.css('.playlist-date-header span')[0].text
end

def format_date date
    unless $base_date
        return Time.now().strftime("%Y-%m-%d @ #{date}")
    end
    "%s @ %s" % [$base_date, date]
end

def lookup_song artist, song
    $songs.each do |date, sartist, ssong, year, prop_name, id|
        if [sartist, ssong] == [artist, song]
            return [date,sartist,ssong,year,prop_name,id]
        end
    end
    nil
end

def known_time clock
    $songs.each do |date, artist, title, year, prop_name, id|
        return true if clock == date
    end
    return false
end

def save_song_database
    FileUtils.cp DB, DBBKUP
    csv = CSV.open(DBTMP, 'wb')
    $songs.each do |data|
        csv << data
    end
    csv.close
    File.rename DBTMP, DB
end

def load_song_database
    $songs = CSV.read(DB)
    $songs.each do |xs|
        $artists[xs[1]] = [xs[4], xs[5]]
    end
end

def load_playlist 
    doc = Nokogiri::HTML(File.open(SETLIST))
    query_date doc
    doc
end

def get_release_date aid, title
    trace "::: Querying song info for: %s" % [title]
    query = "\\\"%s\\\" AND arid:%s" % [CGI.escape(title), CGI.escape(aid)]
    `wget -q -O release.xml "https://musicbrainz.org/ws/2/recording?query=#{query}"`
    doc = Nokogiri::XML(File.open('release.xml'))
    year = best_album_match doc
    FileUtils.rm 'release.xml'
    year
end

def get_artist_id name
    unless $artists.include? name
        trace "::: Querying artist information: '%s'" % [name]
        safe_name = CGI.escape(name)
        `wget -q -O artist.xml https://musicbrainz.org/ws/2/artist/?query=#{safe_name}`
        doc = Nokogiri::XML(File.open('artist.xml'))
        proper_name, id, score = best_artist_match doc
        FileUtils.rm 'artist.xml'
        unless id
            trace "  ... Artist not found"
            return nil
        end
        trace "  ... %s : %s" % [proper_name, id]
        $artists[name] = [proper_name, id]
    end
    return $artists[name]
end

def build_song_info date, artist, song
    pname, aid = get_artist_id artist
    unless aid
        trace "Failed to lookup artist id for: '%s'" % [artist]
        return nil
    end
    year = get_release_date aid, song
    unless year
        trace "Failed to lookup release info for: '%s'" % [song]
        return nil
    end
    $songs << [date, artist, song, year, pname, aid]
    return $songs.size
end

def add_song date, artist, title
    if known_time date
        trace "Duplicate: %s" % [date]
        return
    end
    detail = lookup_song artist, title
    unless detail.nil?
        trace "Known artist/song combo; reusing existing information"
        detail[0] = date
        $songs << detail
        puts "Added song #%d (%s by %s)" % [$songs.size, title, artist]
        return
    end
    song_num = build_song_info date, artist, title
    if song_num
        puts "Added song #%d (%s by %s)" % [song_num, title, artist]
    else
        raise
    end
end

def get_setlist
    FileUtils.rm_f SETLIST
    puts "Loading most recent setlist..."
    `wget -q -O #{SETLIST} https://radio1045.iheart.com/music/recently-played/`
    puts "...done"
    unless File.exists? SETLIST
        puts "Failed to generate setlist. Exiting"
        exit 1
    end
end

def make_plot
    `Rscript --vanilla plot.R`
end




get_setlist
load_song_database
doc = load_playlist

doc.css('.playlist-track-container').each do |item| 
    artist, title, date = "", "", ""
    begin
        artist = item.css('.track-artist')[0].text.strip
        title = item.css('.track-title')[0].text.strip
        date = format_date(item.css('figcaption span')[0].text.strip)
        add_song date, artist, title
        sleep(rand(10) + 5)
    rescue
        aid = ""
        if $artists.include? artist
            aid = $artists[artist][1]
        end
        begin
            fails = File.open('failed_songs.txt', 'ab')
            fails.puts " xx->  ARTIST: '%s' %s" % [artist, aid]
            fails.puts " xx->  TITLE : '%s'" % [title]
            fails.puts " xx->  DATE  : '%s'" % [date]
            fails.close
        rescue
        end
        puts " xx->  ARTIST: '%s' %s" % [artist, aid]
        puts " xx->  TITLE : '%s'" % [title]
        puts " xx->  DATE  : '%s'" % [date]
        sleep(rand(10) + 5)
    end
end

save_song_database
make_plot
