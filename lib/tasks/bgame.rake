namespace :bgame do
  desc "TODO"
  task fetch_games: :environment do
    BgamesController.new.crawl_games
    BgamesMailer.todays_games_email.deliver!
  end
end
