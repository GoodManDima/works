class Api::V2::Admin::LocationsController < Api::V2::Base::LocationsController
  before_action :set_location, only: [:show, :update, :destroy]
  def index
    asc = params[:asc] == "true" ? 'asc' : 'desc'
    order_by = "#{params[:order]} #{asc}"
    locations = Location.where("name ILIKE ?", "%#{params[:query]}%").order(order_by).page(params[:page]).per(50)
    respond_to do |format|
      format.json { render json: { locations: locations, count: locations.total_count }, status: :ok }
    end
  end

  def search_by_query
    locations = Location.where("name ILIKE ?", "%#{params[:term]}%").limit(10).pluck(:name)
    respond_to do |format|
      format.json { render json: locations, root: false, status: :ok }
    end
  end

  def show
    respond_to do |format|
      format.json { render json: @location, status: :ok }
    end
  end

  def join
    Location.join_in_one(params[:name], params[:location_ids])
    respond_to do |format|
      format.json { render json: { text: "Локации успешно объединены" }, status: :ok }
    end
  end

  def update
    @location.attributes = location_params
    respond_to do |format|
      if @location.save
        format.json { render json: { text: "Локация '#{@location.name}' успешно обновлена." }, status: :ok }
      else
        format.json { render json: { text: "Не удалось обновить локацию '#{@location.name}'." }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @location.remove
      render json: { text: "Локация успешно удалена." }, status: :ok
    else
      render json: { text: "Ошибка. Локация не удалена." }, status: :unprocessable_entity
    end
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end

  def location_params
    params.require(:location).permit(
      :name,
      :show,
      :dropdown
    )
  end
end
