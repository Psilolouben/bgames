require 'httparty'
require 'net/http'
require 'curb'
require 'nokogiri'

class Bgame < ActiveRecord::Base
  scope :starting_with_a, -> { where('name like \'A%\'') }
  scope :todays, -> { where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_day, DateTime.now.end_of_day) }
  scope :in_stock, -> { where(in_stock: true) }

  attr_accessor :bgames

  def self.crawl_games
    # Fetch in stock
    currently_in_stock = fetch_in_stock
    # Get instock info
    # Set out of stock
  end

  def self.get_diff
    @bgames = Bgame.all.to_a
    previous = Bgame.in_stock.to_a
    fetch_in_stock
    current = Bgame.in_stock.to_a

    previous - current | current - previous
  end

  private

  def self.fetch_in_stock
    Bgame.update_all(in_stock: false)

    @iteration = 1

    while @iteration <= 20
      puts "Now iterating page: " + @iteration.to_s + " at #{Time.now.to_s}"

      url = "https://www.thegamerules.com/epitrapezia-paixnidia?limit=100&fq=1&page=#{@iteration}"
      url_parsed = URI.parse(url)
      response = Net::HTTP.get_response(url_parsed)

      response.body.split('<div class="name">').each do |i|
        begin
          game_name = i.split('</a></div><div')[0].split('>')[1].encode("UTF-8").gsub("(Exp)", "")
            .gsub("(Exp.)", "").gsub(/\(.*\)/, "").gsub("&amp;", "")
            .gsub("(","").gsub(")","").gsub(": ", ":").strip.squish.encode('utf-8')

          next if game_name.blank?

          # Get from existing if exists
          game_id = fetch_game_id(game_name)
          game_info = fetch_game_info(game_id)

          current_game = Bgame.find_or_initialize_by(id: game_id)
          current_game.assign_attributes(
            name: game_name,
            bgg_id: game_id,
            voters: game_info[:voters],
            score: game_info[:score],
            in_stock: true
          )

          current_game.save!
        rescue => e
          File.open('./missing.log', 'a') { |file| file.write("Missing info for #{game_name}\n") }
          next
        end
      end
      @iteration += 1
    end
  end

  def self.fetch_game_id(name)
    existing = @bgames.select{|n| n.name == name}&.first
    return existing.id if existing

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
    existing = @bgames.select{|n| n.bgg_id == id}&.first
    return { voters: existing.voters, score: existing.score } if existing

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

  def self.calculate_auction_money(geeklist_id)
    response = HTTParty.get("https://www.boardgamegeek.com/xmlapi2/geeklist/#{geeklist_id}?comments=1").body
    while response.include?('Your request for this geeklist has been accepted and will be processed')
      response = HTTParty.get("https://www.boardgamegeek.com/xmlapi2/geeklist/#{geeklist_id}?comments=1").body
      sleep(1)
    end

    response = HTTParty.get("https://www.boardgamegeek.com/xmlapi2/geeklist/#{geeklist_id}?comments=1").body
    hsh = Nokogiri::XML(response)

    money = 0
    hsh.search("geeklist").search("item").each do |itm|
      next if itm.search("comment").blank?

      money += itm.search("comment").map{|x| x.children.text.gsub(/[^\d]/, '').to_i }.max
    end;0

    money
  end

  def self.give_presents(geeklist_id, n)
    winners = []

    pot, bidders = get_bids(geeklist_id)

    n.times do
      winner = pot.sample
      winners << winner
      pot -= [winner]
    end

    return winners.map(&:keys).flatten, bidders.sort_by{ |_, v| v}.reverse.take(n)
  end

  def self.get_bids(geeklist_id)
    response = HTTParty.get("https://www.boardgamegeek.com/xmlapi/geeklist/#{geeklist_id}?comments=1").body
    hsh = Nokogiri::XML(response)

    pot = []
    bidders = {}
    hsh.search("geeklist").search("item").each do |itm|
      next if itm.search("comment").blank?

      highest_bidder = itm.search('comment').
        map{|x| { username: x['username'], bid: x.children.text.gsub(/[^\d]/, '').to_i } }.max_by{|k| k[:bid]}

      if !bidders[highest_bidder[:username]]
        bidders[highest_bidder[:username]] = highest_bidder[:bid]
      else
        bidders[highest_bidder[:username]] += highest_bidder[:bid]
      end

      itm.search("comment").map do |x|
        amount =  x.children.text.gsub(/[^\d]/, '').to_i
        next if amount.zero?

        pot << { x['username'] => amount }


      end
    end;0

    return pot, bidders
  end
end
