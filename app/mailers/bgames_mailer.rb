class BgamesMailer < ApplicationMailer
  default from: "marky.rigas@gmail.com"

  def todays_games_email
    mail(to: ["marky.rigas@gmail.com", "Lamaggra@hotmail.com"], subject: 'Today @ Game Rules')
  end
end
