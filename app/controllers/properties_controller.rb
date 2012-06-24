class PropertiesController < ActionController::Base
  
  def index
    @properties = ZillowProperty.order("price/rentzestimate").all
  end
  
  def import_more
    ZillowProperty.import_more_properties
    redirect_to :action => 'index'
  end
  
end
