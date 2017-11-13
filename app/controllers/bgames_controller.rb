class BgamesController < ApplicationController
  before_action :set_bgame, only: [:show, :edit, :update, :destroy]

  # GET /bgames
  # GET /bgames.json
  def index
    @bgames = Bgame.all.sort_by { |n| n.name }
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
end
