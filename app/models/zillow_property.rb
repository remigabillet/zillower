class ZillowProperty < ActiveRecord::Base
  attr_accessible :price, :info, :url, :rentzestimate, :zestimate
  
  ZILLOW_SEARCH_URL = "http://www.zillow.com/homes/Oakland-CA_rb/#/homes/for_sale/Oakland-CA/fsba,fsbo,new_lt/apartment_condo,duplex,mobile,land_type/13072_rid/1-_beds/180000-250000_price/650-903_mp/37.927138,-121.949959,37.734069,-122.507515_rect/10_zm/0_mmm/"



  
  # Importer
  
  def self.import_more_properties
    properties = self.scrape

    puts "Getting details on #{properties.size} properties..."

    properties.each_pair do |zpid, details|
      merge_property_details(zpid, details)
      print '.'
    end  

    true
  end
  
  
  def self.scrape
    print "Scraping Oakland listings..."

    properties = {}
    resp =  Typhoeus::Request.get(ZILLOW_SEARCH_URL)
    doc = Hpricot(resp.body)
    elements = doc/'//*[@id="search-results"]/li'
    elements.each do |li|
      zpid = li.attributes['id'].gsub('zpid_','').to_i

      price_el = li/'//*[@class="price"]'
      price = price_el.first.to_plain_text.gsub(/\$|,/,'').to_i

      info_el = li/'//*[@class="prop-cola"]'
      info = price_el.first.to_plain_text

      properties[zpid] = { :price => price.to_i, :info => info }
    end

    puts " Done."
    properties
  end

  def self.merge_property_details(zpid, details)
    resp = Rubillow::HomeValuation.zestimate({ 
      :zpid => zpid,
      :rentzestimate => true 
    })

    xml = resp.parser

    details.merge!({
      :url      => xml.xpath('//homedetails').first.text,
      # :useCode  => xml.xpath('//useCode').first.text,
      :rentzestimate     => xml.xpath('//rentzestimate/amount').first.text,
      :zestimate => xml.xpath('//zestimate/amount').first.text,
      # :bedrooms => xml.xpath('//bedrooms').first.text
    })
    
    m = find_or_create_by_zpid(zpid)
    m.update_attributes(details)

    details
  end
end
