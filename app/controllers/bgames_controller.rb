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
      while @iteration <= 10
        @bgames = []
        iterationStr = @iteration == 1 ? "1-150" : ((@iteration-1)*150).to_s + "-" + (@iteration*150).to_s
        #iterationStr = @iteration.to_s
        puts "Now iterating: " + iterationStr + " at #{Time.now.to_s}"
        url = "https://www.thegamerules.com/el/funko-pop/funky-games/world-of-warcraft/search/by,%60p%60.product_availability/dirAsc/results," + iterationStr + "?language=el-GR&filter_product="
        #url = "https://www.thegamerules.com/el/arxiki?start=#{@iteration}"
        url_parsed = URI.parse(url)
        response = Net::HTTP.get_response(url_parsed)
        splitresponse = response.body.split('catProductTitle')
        splitresponse[0..150].each do |item|
          i = item.split('>')[2].split('<')[0]
          next if (i.include? 'Sleeves') || (i.include? 'Dice Set') || (i.include? 'Organizer') || (i.include? 'D6') ||
          (i.include? 'Tokens') || (i.include? '&')
          bgm = Bgame.new
          begin
            bgm.name = i.encode("UTF-8").gsub("(Exp)", "")
            .gsub("(Exp.)", "").gsub(/\(.*\)/, "")
            .gsub("(","").gsub(")","").strip.squish
            bgm.id = 0
            @bgames << bgm unless bgm.name == "\n"
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
            #response = HTTParty.get('https://www.boardgamegeek.com/xmlapi/search?search=' + bg.name, timeout: 20).body
            hsh = Hash.from_xml(response.gsub("\n", ""))
            if hsh["items"]["item"].is_a? Hash
            #if hsh["boardgames"]["boardgames"].is_a? Hash
              bg.bgg_id = hsh["items"]["item"]["id"].to_i
              #bg.bgg_id = hsh["boardgames"]["boardgame"]["objectid"].to_i
            else
              bg.bgg_id = hsh["items"]["item"].select{|s| s["name"]["type"]=="primary"}.first["id"].to_i
            #bg.bgg_id = hsh["boardgames"]["boardgame"].select{|s| s["name"]["type"]=="primary"}.first["objectid"].to_i
            end
            @current_search_bgames[bg.bgg_id] = bg.name
          else
            bg.bgg_id = @existing.bgg_id
            bg.name = @existing.name
            bg.voters = @existing.voters
            bg.rating = @existing.rating
            bg.score = WilsonScore.rating_lower_bound(@existing.rating.to_f, @existing.voters, 1..10)
            @ret_bgames << bg unless @ret_bgames.select{|b| b.bgg_id == bg.bgg_id}.count > 0
          end
          rescue StandardError => exc
            next
          end
        end
        puts "Iterated: " + iterationStr
        @iteration += 1
        #@iteration += 30
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
      #  #bg.voters = hsh["boardgames"]["boardgame"]["statistics"]["ratings"]["usersrated"]["value"].to_i
      #  #bg.rating = hsh["boardgames"]["boardgame"]["statistics"]["ratings"]["average"]["value"].to_f
            bgame.bgg_id = bg["id"].to_i
            bgame.name = @current_search_bgames[bgame.bgg_id]
            bgame.score = WilsonScore.rating_lower_bound(bgame.rating.to_f, bgame.voters, 1..10)
            bgame.save
            @ret_bgames << bgame
          end
        else
          bgame = Bgame.new()
          bgame.rating = hsh["items"]["item"]["statistics"]["ratings"]["average"]["value"].to_f
          bgame.voters = hsh["items"]["item"]["statistics"]["ratings"]["usersrated"]["value"].to_i
    #  #bg.voters = hsh["boardgames"]["boardgame"]["statistics"]["ratings"]["usersrated"]["value"].to_i
    #  #bg.rating = hsh["boardgames"]["boardgame"]["statistics"]["ratings"]["average"]["value"].to_f
          bgame.bgg_id = hsh["items"]["item"]["id"].to_i
          bgame.name = @current_search_bgames[bgame.bgg_id]
          bgame.score = WilsonScore.rating_lower_bound(bgame.rating.to_f, bgame.voters, 1..10)
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
      #@bgames = Bgame.all.sort_by { |n| n.name }
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
