require 'httparty'
require 'net/http'
require 'curb'

class Bgame < ActiveRecord::Base
  scope :starting_with_a, -> { where('name like \'A%\'') }
  scope :todays, -> { where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_day, DateTime.now.end_of_day) }

  def self.crawl_games
    # Fetch in stock
    currently_in_stock = fetch_in_stock
    # Get instock info
    # Set out of stock
  end

  private

  def self.fetch_in_stock
    @iteration = 1
    @bgames = []

    while @iteration <= 20
      puts "Now iterating page: " + @iteration.to_s + " at #{Time.now.to_s}"

      url = "https://www.thegamerules.com/epitrapezia-paixnidia?limit=10&fq=1&page=#{@iteration}"
      url_parsed = URI.parse(url)
      response = Net::HTTP.get_response(url_parsed)

      response.body.split('<div class="name">').each do |i|
        begin
        game_name = i.split('</a></div><div')[0].split('>')[1].encode("UTF-8").gsub("(Exp)", "")
          .gsub("(Exp.)", "").gsub(/\(.*\)/, "").gsub("&amp;", "")
          .gsub("(","").gsub(")","").gsub(": ", ":").strip.squish.encode('utf-8')

        next if game_name.empty?

        # Get from existing if exists
        game_id = fetch_game_id(game_name)
        game_info = fetch_game_info(game_id)
        Bgame.create(
          name: game_name,
          bgg_id: game_id,
          voters: game_info[:voters],
          score: game_info[:score],
          in_stock: true
        )
        rescue => e
          puts "Missing info for #{game_name}"
          next
        end
      end
      @iteration += 1
    end

    @bgames
  end

  def self.fetch_game_id(name)
    #Bgame.where(name: name).any
    response = HTTParty.get('https://www.boardgamegeek.com/xmlapi2/search?query=' + CGI.escape(name) + "&type=boardgame").body
    sleep(1)
    hsh = Hash.from_xml(response.gsub("\n", ""))
    if hsh["items"]["item"].is_a? Hash
      bgg_id = hsh["items"]["item"]["id"].to_i
    else
      bgg_id = hsh["items"]["item"].select{|s| s["name"]["type"]=="primary"}.first["id"].to_i
    end
  end

  def self.fetch_game_info(id)
    response = HTTParty.get('https://www.boardgamegeek.com/xmlapi2/thing?id=' + id.to_s + "&stats=1").body
    hsh = Hash.from_xml(response.gsub("\n", ""))
    rating = hsh["items"]["item"]["statistics"]["ratings"]["average"]["value"].to_f
    voters = hsh["items"]["item"]["statistics"]["ratings"]["usersrated"]["value"].to_i
    {
      rating: hsh["items"]["item"]["statistics"]["ratings"]["average"]["value"].to_f,
      voters: voters,
      score: (rating != 0 && voters != 0) ? WilsonScore.rating_lower_bound(rating, voters, 1..10) : 0
    }
  end
end
