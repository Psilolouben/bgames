namespace :bgame do
  desc "TODO"
  task fetch_games: :environment do
    BgamesMailer.todays_games_email.deliver!
  end
end
