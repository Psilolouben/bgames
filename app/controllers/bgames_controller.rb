  require 'httparty'
  require 'net/http'
  require 'curb'
  class BgamesController < ApplicationController

    before_action :set_bgame, only: [:show, :edit, :update, :destroy]

    def index
      @ret_bgames = []
    end
    # GET /bgames
    # GET /bgames.json
    def crawl
      @ret_bgames = []
      @db_games = Bgame.all

      @iteration = 1
      #@iteration = 0
      @current_search_bgames={}
      #while @iteration < 5130
      while @iteration <= 16
        @bgames = []

        puts "Now iterating page: " + @iteration.to_s + " at #{Time.now.to_s}"

        url = "https://www.thegamerules.com/epitrapezia-paixnidia?limit=100&fq=1&page=#{@iteration}"
        url_parsed = URI.parse(url)
        response = Net::HTTP.get_response(url_parsed)

        response.body.split('<div class="name">').each do |i|
          bgm = Bgame.new
          begin
            bgm.name = i.split('</a></div><div')[0].split('>')[1].encode("UTF-8").gsub("(Exp)", "")
            .gsub("(Exp.)", "").gsub(/\(.*\)/, "").gsub("&amp;", "")
            .gsub("(","").gsub(")","").strip.squish.encode('utf-8')
            bgm.id = 0

            unfound =  UnfoundBgame.where(bgname: bgm.name).any?
            @bgames << bgm unless bgm.name == "\n" || unfound
          rescue
            next
          end
        end

        @bgames.each do |bg|
        begin
          @existing = @db_games.where(name: bg.name).first
          if @existing.nil?
            response = HTTParty.get('https://www.boardgamegeek.com/xmlapi2/search?query=' + CGI.escape(bg.name) + "&exact=1&type=boardgame,boardgameexpansion").body
            sleep(1)
            hsh = Hash.from_xml(response.gsub("\n", ""))
            if hsh["items"]["item"].is_a? Hash
              bg.bgg_id = hsh["items"]["item"]["id"].to_i
            else
              bg.bgg_id = hsh["items"]["item"].select{|s| s["name"]["type"]=="primary"}.first["id"].to_i
            end
            @current_search_bgames[bg.bgg_id] = bg.name
          else
            bg.bgg_id = @existing.bgg_id
            bg.name = @existing.name
            bg.voters = @existing.voters
            bg.rating = @existing.rating
            bg.score = (bg.rating != 0 && bg.voters != 0) ? WilsonScore.rating_lower_bound(@existing.rating.to_f, @existing.voters, 1..10) : 0
            @ret_bgames << bg unless @ret_bgames.select{|b| b.bgg_id == bg.bgg_id}.count > 0
          end
          rescue StandardError => exc
            if UnfoundBgame.exists?(bgname: "")
              ubg = UnfoundBgame.new
              ubg.bgname = bg.name
              ubg.save
            end
            next
          end
        end
        puts "Iterated Page: " + @iteration.to_s
        @iteration += 1
      end

      query = @current_search_bgames.keys.join(',')
      if query != ""
        response = HTTParty.get('https://www.boardgamegeek.com/xmlapi2/thing?id=' + query.to_s + "&stats=1").body
        hsh = Hash.from_xml(response.gsub("\n", ""))
        if @current_search_bgames.count > 1
          hsh["items"]["item"].each do |bg|
            bgame = Bgame.new()
            bgame.rating = bg["statistics"]["ratings"]["average"]["value"].to_f
            bgame.voters = bg["statistics"]["ratings"]["usersrated"]["value"].to_i
            bgame.bgg_id = bg["id"].to_i
            bgame.name = @current_search_bgames[bgame.bgg_id]
            bgame.score = (bgame.rating != 0 && bgame.voters != 0) ? WilsonScore.rating_lower_bound(bgame.rating.to_f, bgame.voters, 1..10) : 0
            bgame.save
            @ret_bgames << bgame
          end
        else
          bgame = Bgame.new()
          bgame.rating = hsh["items"]["item"]["statistics"]["ratings"]["average"]["value"].to_f
          bgame.voters = hsh["items"]["item"]["statistics"]["ratings"]["usersrated"]["value"].to_i
          bgame.bgg_id = hsh["items"]["item"]["id"].to_i
          bgame.name = @current_search_bgames[bgame.bgg_id]
          bgame.score =(bgame.rating != 0 && bgame.voters != 0) ? WilsonScore.rating_lower_bound(bgame.rating.to_f, bgame.voters, 1..10) : 0
          bgame.save
          @ret_bgames << bgame
        end
      end
      @ret_bgames.each_with_object([]) do |ob,arr|
        if ob.score.nil?
          ob.score = 0
        end
        arr << ob
      end
      @ret_bgames = @ret_bgames.find_all{|x| !x.rating.nil?}.sort_by { |n| n.score }.reverse

      render 'index'
    end


  def filter
    @db_games = Bgame.all
    @bgames = []
    @bgames << Bgame.new(name: params[:str_filter], id: 0)
    @bgames.each do |bg|
      begin
        @existing = @db_games.where(name: bg.name).first
        if @existing.nil?
          response = HTTParty.get('https://www.boardgamegeek.com/xmlapi2/search?query=' + bg.name + "&exact=1&type=boardgame,boardgameexpansion").body
          hsh = Hash.from_xml(response.gsub("\n", ""))
          if hsh["items"]["item"].is_a? Hash
            bg.bgg_id = hsh["items"]["item"]["id"].to_i
          else
            bg.bgg_id = hsh["items"]["item"].select{|s| s["name"]["value"].upcase==bg.name.upcase}.first["id"].to_i
          end
          if bg.bgg_id
            response = HTTParty.get('https://www.boardgamegeek.com/xmlapi2/thing?id=' + bg.bgg_id.to_s + "&stats=1").body
            hsh = Hash.from_xml(response.gsub("\n", ""))
            bg.voters = hsh["items"]["item"]["statistics"]["ratings"]["usersrated"]["value"].to_i
            bg.rating = hsh["items"]["item"]["statistics"]["ratings"]["average"]["value"].to_f
            bgame = Bgame.new()
            bgame.name=bg.name
            bgame.bgg_id = bg.bgg_id
            bgame.rating = bg.rating
            bgame.voters = bg.voters
            bgame.save
          end
        else
          bg.bgg_id = @existing.bgg_id
          bg.name = @existing.name
          bg.voters = @existing.voters
          bg.rating = @existing.rating
        end
      rescue StandardError => exc
        next
      end
    end

    render 'index'
  end

  # GET /bgames/1
  # GET /bgames/1.json
  def show
  end

  # GET /bgames/new
  def new
    @bgame = Bgame.new
  end

  # GET /bgames/1/edit
  def edit
  end

  # POST /bgames
  # POST /bgames.json
  def create
    @bgame = Bgame.new(bgame_params)

    respond_to do |format|
      if @bgame.save
        format.html { redirect_to @bgame, notice: 'Bgame was successfully created.' }
        format.json { render :show, status: :created, location: @bgame }
      else
        format.html { render :new }
        format.json { render json: @bgame.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /bgames/1
  # PATCH/PUT /bgames/1.json
  def update
    respond_to do |format|
      if @bgame.update(bgame_params)
        format.html { redirect_to @bgame, notice: 'Bgame was successfully updated.' }
        format.json { render :show, status: :ok, location: @bgame }
      else
        format.html { render :edit }
        format.json { render json: @bgame.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /bgames/1
  # DELETE /bgames/1.json
  def destroy
    @bgame.destroy
    respond_to do |format|
      format.html { redirect_to bgames_url, notice: 'Bgame was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_bgame
    @bgame = Bgame.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def bgame_params
    params.require(:bgame).permit(:name, :bgg_id)
  end

  def price_of_item
    #@url = "https://www.thegamerules.com/index.php?option=com_virtuemart&nosef=1&view=productdetails&task=recalculate&virtuemart_product_id=1065&format=json"
    #@result = Curl::Easy.perform(@url) do |curl|
    #curl.head = true
    #curl.follow_location = true
    #end
    #@result.last_effective_url
    #@result.get
    #price = JSON.parse(@result.body)['salesPrice']

    #return price
  end

  helper_method :price_of_item

end
