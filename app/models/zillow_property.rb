class ZillowProperty < ActiveRecord::Base
  attr_accessible :price, :info, :url, :rentzestimate, :zestimate, :address, :photo_url, :property_type, :sq_ft, :bathrooms, :bedrooms
  
  ZILLOW_SEARCH_URL = "http://www.zillow.com/homes/Oakland-CA_rb/#/homes/for_sale/Oakland-CA/fsba,fsbo,new_lt/apartment_condo,duplex,mobile,land_type/13072_rid/1-_beds/180000-250000_price/650-903_mp/37.927138,-121.949959,37.734069,-122.507515_rect/10_zm/0_mmm/"



  
  # Importer
  
  def self.import_more_properties
    properties_scraped = self.new_scrape

    puts "Getting details on #{properties_scraped.size} properties..."

    properties_imported = []
    properties_scraped.each_pair do |zpid, details|
      p = find_or_create_by_zpid(zpid)
      p.update_attributes(details)
      # p.merge_home_valuation
      # p.merge_deep_details
      print '.'
    end  

    true
  end
  
  
  def self.scrape
    print "Scraping Oakland listings..."

    properties = {}
    resp =  Typhoeus::Request.get(ZILLOW_SEARCH_URL, :headers => { 'User-Agent' => 'Mozilla/5.0 (Windows NT 6.0) AppleWebKit/536.5 (KHTML, like Gecko) Chrome/19.0.1084.36 Safari/536.5' })
    doc = Hpricot(resp.body)
    elements = doc/'//*[@id="search-results"]/li'
    elements.each do |li|
      zpid = li.attributes['id'].gsub('zpid_','')

      price_el = li/'//*[@class="price"]'
      price = price_el.first.to_plain_text.gsub(/\$|,/,'').to_i

      info_el = li/'//*[@class="prop-cola"]'
      info = price_el.first.to_plain_text

      properties[zpid] = { :price => price.to_i, :info => info }
    end

    puts " Done."
    properties
  end
  
  def self.new_scrape
    response =  Typhoeus::Request.get('http://www.zillow.com/search/GetResults.htm', :params => {
      :status => 10000,
      :lt => 11110,
      :ht => 11111,
      :pr => '150000,400000',
      :mp => "542,1446",
      :bd => 1,
      :ba => 0,
      :list => nil,
      :sf => 500,
      :lot => nil,
      :yr => nil,
      :pho => 0,
      :red => 0,
      :zso => 0,
      :att => nil,
      :days => 'any',
      :ds => 'all',
      :zoom => 10,
      :rect => '-122483826,37695503,-121973648,37888673',
      :p => 1,
      :sort => 'days',
      :search => 'maplist',
      :disp => 1,
      :rid => 13072,
      :rt => 6
    })
    
    list_html = extract_list_html_from_response(response)

    doc = Hpricot(list_html)
    elements = doc/'//*[@id="search-results"]/li'
        
    properties = {}
    elements.each do |li|
      props = {}
      
      zpid = li.attributes['id'].gsub('zpid_','')

      if adr_el = li.at('//*[@class="adr"]/a')
        props[:address] = adr_el.to_plain_text.gsub(/\s\[.*\]/,'')
        props[:url] = 'http://zillow.com/' + adr_el.attributes['href']
      end
      
      if photo_el = li.at('//*[@class="photo-url"]')
        props[:photo_url] = photo_el.attributes['value']
      end
      
      if price_el = li.at('//*[@class="price"]')
        props[:price] = price_el.to_plain_text.gsub(/\$|,/,'').to_i
      end

      properties[zpid] = props
    end

    puts " Done."
    properties
  end


  def self.extract_list_html_from_response(response)
    str = response.body
    
    # grab the string by substitution
    startStr = 'listHTML":"'
    str.index(startStr)
    startIdx = str.index(startStr) + startStr.length

    endStr = "\"\n},"
    endIdx = str.index(endStr) - 1
    html = str[startIdx..endIdx]
    
    # un-escape JSON by wrapping it all in a JSON key
    return JSON.parse('{"hack":"'+ html + '"}')["hack"]
  end
  

  def merge_home_valuation
    xml = Rubillow::HomeValuation.zestimate({ 
      :zpid => zpid,
      :rentzestimate => true 
    }).parser

    attrs = {
      :url      => xml.xpath('//homedetails').first.text,
      :rentzestimate     => xml.xpath('//rentzestimate/amount').first.text,
      :zestimate => xml.xpath('//zestimate/amount').first.text
    }
    
    update_attributes(attrs)
  end
  
  
  def merge_deep_details
    address_param = address.split(', ')[0]
    citystatezip_param = address.split(', ')[1..-1].join(', ')
    
    xml = Rubillow::PropertyDetails.deep_search_results({ 
      :address => address_param,
      :citystatezip => citystatezip_param,
      :rentzestimate => true 
    }).parser

    unless xml.xpath('//message/text').text.match('Error')
      attrs = {
        :property_type  => xml.xpath('//useCode').first.try(:text),   
        :sq_ft => xml.xpath('//finishedSqFt').first.try(:text),
        :bathrooms => xml.xpath('//bathrooms').first.try(:text),
        :bedrooms => xml.xpath('//bedrooms').first.try(:text),
        :zestimate => xml.xpath('//zestimate/amount').first.try(:text),
        :rentzestimate     => xml.xpath('//rentzestimate/amount').first.try(:text)      
      }
      update_attributes(attrs)
    end
  end
end
