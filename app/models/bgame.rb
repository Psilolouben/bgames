require 'httparty'
require 'net/http'
require 'curb'

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
    sleep(3)
    response = HTTParty.get("https://www.boardgamegeek.com/xmlapi2/geeklist/#{geeklist_id}?comments=1").body
    hsh = Hash.from_xml(response)
    items = hsh['geeklist']['item']

    money = 0
    items.each do |itm|
      next if itm['comment'].nil?
      money += itm['comment'].is_a?(Array) ? itm['comment'].map{|x| x.strip.to_i}.max : itm['comment'].to_i
    end;0

    money
  end

  def self.give_presents(geeklist_id, n)
    winners = []
    response = HTTParty.get("https://www.boardgamegeek.com/xmlapi/geeklist/#{geeklist_id}?comments=1").body
    hsh = Hash.from_xml(response)
    items = hsh['geeklist']['item']

    pot = []
    items.each do |itm|
      next if itm['comment'].nil?

      itm['comment'].is_a?(Array) ?
        itm['comment'].to_a.each do |comm|
          pot << "User that bids #{comm.gsub("\n","")} for item: #{itm['objectname']}" unless comm.strip.to_i.zero?
        end : "User that bids #{itm['comment'].gsub("\n","")} for item: #{itm['objectname']}"
    end;0

    n.times do
      winner = pot.sample
      winners << winner
      pot -= [winner]
    end

    winners
  end
end
