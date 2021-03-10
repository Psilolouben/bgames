  require 'httparty'
  require 'net/http'
  require 'curb'
  class AuctionsController < ApplicationController

    def show
      render 'show'
    end

    def calculate
      @money = Bgame.calculate_auction_money(params['geeklist_id'].first)
      @winners = Bgame.give_presents(params['geeklist_id'].first, params['gifts'].first.to_i)

      render 'show'
    end

    skip_before_action :verify_authenticity_token
  end
