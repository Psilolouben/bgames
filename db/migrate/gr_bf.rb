require 'nokogiri'
require 'csv'
require 'mechanize'
require 'httparty'
require 'pry'

start_time = Time.now
# create Mechanize instance
agent = Mechanize.new

# get the login form & fill it out with the username/password
login_form = agent.get("https://www.blackfire.eu/en-gb/profile/login?returnurl=https%3a%2f%2fwww.blackfire.eu%2fen-gb%2f").forms.last
login_form.UserName = 'info@thegamerules.com'
login_form.Password = 'Gamerules4zyu6yw'

# submit login form
agent.submit(login_form, login_form.buttons.first)
page = 1
cpp = 24
response = HTTParty.get("https://www.blackfire.eu/en-gb/search?q=0&count=#{cpp}&page=#{page}",
  :headers => { 'Cookie' => agent.cookies.map{|x| "#{x.name}=#{x.value}"}.join(';') }).body;0
hsh = Nokogiri::HTML(response){ |conf| conf.noblanks }.search('[class=content]');0
total_games = hsh.search('[class=counter-inside]').children.first.text.strip.to_i
total_pages = ( total_games / cpp) + 1
games = []

while page < total_pages
  begin
    puts "Scanning page #{page}"
    response = HTTParty.get("https://www.blackfire.eu/en-gb/search?q=0&count=#{200}&page=#{page}",
      :headers => { 'Cookie' => agent.cookies.map{|x| "#{x.name}=#{x.value}"}.join(';') }).body;0
    product_list = hsh.search('[class=product-description]')
    product_prices = hsh.search('[class=product-action]')
    eans = product_list.search('[class=product-attributes]').map {|x| x.elements[1].text.strip}
    product_codes = product_list.search('[class=product-attributes]').map {|x| x.elements[0].text.strip}
    titles = product_list.search('[class=product-title]').map{ |x| x.children[1].text }
    availabilities = product_list.search('[class=erpbase_stocklevel]').map{ |x| x.children[1].text }
    prices = product_prices.map{ |x| x.children[3].attributes['content'].value }
    item_no = hsh.search('[class=product-id-value]').map(&:text)

    titles.each_with_index do |obj, idx|
      games << {
        product_code: product_codes[idx],
        ean: eans[idx],
        name: obj,
        availability: availabilities[idx],
        price: prices[idx],
        item_no: item_no[idx]
      }
    end;0

    puts "Total games: #{games.count} / #{cpp * page} of #{total_games}"
    page += 1
  rescue => exception
    agent.submit(login_form, login_form.buttons.first)
    next
  end
end;0

CSV.open("bf_games.csv", "w") do |csv|
  csv << ['Product Code', 'EAN', 'Game', 'Availability', 'Price', 'Item.No']
  games.each do |game|
    csv << [game[:product_code], game[:ean], game[:name], game[:availability], game[:price], game[:item_no]]
  end
end;0

puts "Finished after #{Time.now - start_time} seconds"

