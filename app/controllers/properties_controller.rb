class PropertiesController < ActionController::Base
  
  def index
    @properties = ZillowProperty.order("price/rentzestimate").all
  end
  
end
