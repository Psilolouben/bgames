  require 'httparty'
  require 'net/http'
  require 'curb'
class BgamesController < ApplicationController


  before_action :set_bgame, only: [:show, :edit, :update, :destroy]

  # GET /bgames
  # GET /bgames.json
  def index
    @bgames = []
    url = "https://www.thegamerules.com/el/funko-pop/funky-games/world-of-warcraft/search/by,%60p%60.product_availability/dirAsc/results,1-500?language=el-GR&filter_product="
    url_parsed = URI.parse(url)
    response = Net::HTTP.get_response(url_parsed)
    splitresponse = response.body.split('catProductTitle')
    splitresponse[0..500].each do |item|
      i = item.split('>')[2].split('<')[0]
      bg = Bgame.new
      begin
      bg.name = i.encode("UTF-8").gsub("(Exp)", "replacement")
      .gsub("(Exp.)", "replacement").gsub(/\(.*\)/, "")
      .gsub("(","").gsub(")","")
      bg.id = 0
      @bgames << bg unless bg.name == "\n"
      rescue
        next
      end
    end

    @bgames.each do |bg|
      begin
      #if (bg.name.include? "Agamemnon") || (bg.name.include? "Ravenloft")
       # binding.pry
      #end
        response = HTTParty.get('http://www.boardgamegeek.com/xmlapi/search?search=' + bg.name).body
        hsh = Hash.from_xml(response.gsub("\n", ""))
        bg.bgg_id=hsh["boardgames"]["boardgame"].count == 3 ? hsh["boardgames"]["boardgame"]["objectid"].to_i
        : hsh["boardgames"]["boardgame"].first["objectid"].to_i
        bg.rating = 1
        if bg.bgg_id
         response = HTTParty.get('http://www.boardgamegeek.com/xmlapi/boardgame/' + bg.bgg_id.to_s + "?stats=1").body
          hsh = Hash.from_xml(response.gsub("\n", ""))
          bg.rating = hsh["boardgames"]["boardgame"]["statistics"]["ratings"]["average"].to_f
        end


      rescue StandardError => exc
        next
      end
    end
   @bgames = @bgames.find_all{|x| !x.rating.nil?}.sort_by { |n| n.rating}.reverse
    #@bgames = Bgame.all.sort_by { |n| n.name }
  end

  def filter
    if params[:str_filter].to_s.empty?
      @bgames = Bgame.all.sort_by { |n| n.name }
    else
      @bgames = Bgame.where("name LIKE '%#{params[:str_filter]}%'")
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
    @url = "https://www.thegamerules.com/index.php?option=com_virtuemart&nosef=1&view=productdetails&task=recalculate&virtuemart_product_id=1065&format=json"
    @result = Curl::Easy.perform(@url) do |curl|
    curl.head = true
    curl.follow_location = true
    end
    @result.last_effective_url
    @result.get
    price = JSON.parse(@result.body)['salesPrice']

    return price
  end

  helper_method :price_of_item

end
