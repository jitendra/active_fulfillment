module ActiveMerchant
  module Fulfillment
    class WebgistixService < Service
      TEST_URL = 'http://www.webgistix.com/XML/shippingTest.asp'
      LIVE_URL = 'http://www.webgistix.com/XML/API.asp'
      
      SUCCESS, FAILURE = 'True', 'False'
      SUCCESS_MESSAGE = 'Successfull.'
      FAILURE_MESSAGE = 'Failed.'
      INVALID_LOGIN = 'Access Denied'
      
      # The first is the label, and the last is the code
      def self.shipping_methods
        [ 
          ["UPS Ground Shipping", "Ground"],
          ["UPS Standard Shipping (Canada Only)", "Standard"],
          ["UPS 3-Business Day", "3-Day Select"],
          ["UPS 2-Business Day", "2nd Day Air"],
          ["UPS 2-Business Day AM", "2nd Day Air AM"],
          ["UPS Next Day", "Next Day Air"],
          ["UPS Next Day Saver", "Next Day Air Saver"],
          ["UPS Next Day Early AM", "Next Day Air Early AM"],
          ["UPS Worldwide Express (Next Day)", "Worldwide Express"],
          ["UPS Worldwide Expedited (2nd Day)", "Worldwide Expedited"],
          ["UPS Worldwide Express Saver", "Worldwide Express Saver"],
          ["FedEx Priority Overnight", "FedEx Priority Overnight"],
          ["FedEx Standard Overnight", "FedEx Standard Overnight"],
          ["FedEx First Overnight", "FedEx First Overnight"],
          ["FedEx 2nd Day", "FedEx 2nd Day"],
          ["FedEx Express Saver", "FedEx Express Saver"],
          ["FedEx International Priority", "FedEx International Priority"],
          ["FedEx International Economy", "FedEx International Economy"],
          ["FedEx International First", "FedEx International First"],
          ["FedEx Ground", "FedEx Ground"],
          ["USPS Priority Mail & Global Priority Mail", "Priority"],
          ["USPS First Class Mail", "First Class"],
          ["USPS Express Mail & Global Express Mail", "Express"],
          ["USPS Parcel Post", "Parcel"],
          ["USPS Air Letter Post", "Air Letter Post"],
          ["USPS Media Mail", "Media Mail"],
          ["USPS Economy Parcel Post", "Economy Parcel"],
          ["USPS Economy Air Letter Post", "Economy Letter"],
          ["DHL Express", "DHL Express"],
          ["DHL Next Afternoon", "DHL Next Afternoon"],
          ["DHL Second Day Service", "DHL Second Day Service"],
          ["DHL Ground", "DHL Ground"],
          ["DHL International Express", "DHL International Express"]
        ].inject(ActiveSupport::OrderedHash.new){|h, (k,v)| h[k] = v; h}
      end
      
      # Pass in the customer_id and password for the shipwire account.
      # Optionally pass in the :test => true to force test mode
      def initialize(options = {})
        requires!(options, :customer_id, :password)
        super
      end

      def fulfill(order_id, shipping_address, line_items, options = {})  
        requires!(options, :shipping_method)
        @url = test? ? TEST_URL : LIVE_URL
        commit :fulfillment, build_fulfillment_request(order_id, shipping_address, line_items, options)
      end
      
      def inventory
        @url = "http://www.webgistix.com/XML/InventorySvc.asp"
        commit :inventory, build_inventory_request#(options ={})
      end
      
      def track(orders, options = {}) #orders is array of orders to be track.
        requires!(options, :username)
        @url = "http://www.webgistix.com/XML/TrackingSvc.asp"
        commit :tracking, build_track_order_request(orders, options)
      end
      
      def create_item(items, options = {}) #items is array of items
        @url = "http://www.webgistix.com/XML/createItem.asp"
        commit :creation, build_create_item_request(items, options)
      end
      
      def valid_credentials_for_fulfill?
        response = fulfill('', {}, [], :shipping_method => '')
        response.message != INVALID_LOGIN
      end

      def valid_credentials_for_inventory?
        response = inventory
        response.message != INVALID_LOGIN
      end
      
      def valid_credentials_for_tracking?(options = {})
        response = track([], options)
        response.message != INVALID_LOGIN
      end
      
      def valid_credentials_for_creation?
        response = create_item([], {})
        response.message != INVALID_LOGIN
      end
   
      def test_mode?
        true
      end

      private
      
      def build_fulfillment_request(order_id, shipping_address, line_items, options)
        address_xml = <<-EOS
          <?xml version="1.0"?> 
          <OrderXML> 
            <Password>#{@options[:password]}</Password> 
            <CustomerID>#{@options[:customer_id]}</CustomerID> 
            <Order> 
              <ReferenceNumber>#{order_id}</ReferenceNumber> 
              <Company>#{shipping_address[:company]}</Company> 
              <Name>#{shipping_address[:name]}</Name> 
              <Address1>#{shipping_address[:address1]}</Address1>
              <City>#{shipping_address[:city]}</City> 
              <State>#{shipping_address[:state]}</State> 
              <ZipCode>#{shipping_address[:zip]}</ZipCode> 
              <Country>#{shipping_address[:country]}</Country> 
              <Phone>#{shipping_address[:phone]}</Phone>
        EOS
        address_xml += "<Address2>#{shipping_address[:address2]}</Address2>" if shipping_address[:address2]
        address_xml += "<Address3>#{shipping_address[:address3]}</Address3>" if shipping_address[:address3]      
        other_info_xml = <<-EOS     
          <Email>#{options[:email]}</Email>      
          <ShippingInstructions>#{options[:shipping_method]}</ShippingInstructions> 
          <Approve>1</Approve>
        EOS
        address_xml += other_info_xml      
        address_xml += "<OrderComments>#{options[:order_comments]}</OrderComments>" if options[:order_comments]
        line_items.each {|item| address_xml += "<Item><ItemID>#{item[:sku]}</ItemID><ItemQty>#{item[:quantity]}</ItemQty></Item>"}
        xml = address_xml + "</Order></OrderXML>"
      end
      
      def build_inventory_request
        xml = <<-EOS
          <?xml version="1.0"?> 
          <InventoryXML> 
            <Password>#{@options[:password]}</Password> 
            <CustomerID>#{@options[:customer_id]}</CustomerID> 
          </InventoryXML>
        EOS
      end
      
      def build_track_order_request(orders, options)
        credentials_xml = <<-EOS
        <?xml version="1.0"?> 
        <TrackingXML> 
          <Username>#{options[:username]}</Username> 
          <Password>#{@options[:password]}</Password> 
          <Customer>#{@options[:customer_id]}</Customer> 
        EOS
        orders.each {|order| credentials_xml += "<Tracking><Order>#{order[:order_id]}</Order></Tracking>"}
        xml = credentials_xml + "</TrackingXML>"
      end
      
      def build_create_item_request(items, options)
        credentials_xml = <<-EOS
          <?xml version="1.0"?> 
          <ItemXML> 
            <Password>#{@options[:password]}</Password> 
            <Customer>#{@options[:customer_id]}</Customer> 
         EOS
         items.each {|item| credentials_xml += "<Item><ItemID>#{item[:sku]}</ItemID><ShortDescription>#{item[:description]}</ShortDescription><Category>#{item[:category]}</Category><UnitPrice>#{item[:unit_price]}</UnitPrice></Item>" }
         xml = credentials_xml + "</ItemXML>"
      end

      def commit(action, request)
        p request
        @response = parse_response(action, ssl_post(@url, request, 'EndPointURL'  => @url, 'Content-Type' => 'text/xml; charset="utf-8"'))
        Response.new(success?(@response), message_from(@response), @response, :test => test?)
      end
      
      def success?(response)
        response[:success] == SUCCESS
      end
      
      def message_from(response)
        return SUCCESS_MESSAGE if success?(response)

        if response[:error_0] == INVALID_LOGIN
          INVALID_LOGIN
        else
          FAILURE_MESSAGE
        end
      end
      
      def parse_response(action, data)
        case action
        when :fulfillment
          parse_fulfillment_response(data)        
        when :inventory
          parse_inventory_response(data)
        when :tracking
          parse_tracking_response(data)
        when :creation
          parse_creation_response(data)
        else
          raise ArgumentError, "Unknown action #{action}"
        end
      end
      
      def parse_fulfillment_response(xml)
        response = {}
        
        begin 
          document = REXML::Document.new("<response>#{xml}</response>")
        rescue REXML::ParseException
          response[:success] = FAILURE
          return response
        end
        # Fetch the errors
        document.root.elements.to_a("Error").each_with_index do |e, i|
          response["error_#{i}".to_sym] = e.text
        end
        # Check if completed
        if completed = REXML::XPath.first(document, '//Completed')
          completed.elements.each do |e|
            response[e.name.underscore.to_sym] = e.text
          end
        else
          response[:success] = FAILURE
        end  
        response
      end
      
      def parse_inventory_response(xml)
        response = {}
        begin
          document = REXML::Document.new("<response>#{xml}</response>")
        rescue REXML::ParseException
          response[:success] = FAILURE
          return response
        end
        
        #Fetch the errors
        document.root.elements.to_a("Error").each_with_index do |e, i|
          response["error_#{i}".to_sym] = e.text
        end
        
        if REXML::XPath.first(document, '//InventoryXML')
          result = Hash.from_xml("<response>#{xml}</response>")
          response[:success] = SUCCESS
          response.merge!(result)
        else
          response[:success] = FAILURE
        end
        response
      end
      
      def parse_tracking_response(xml)
        response = {}
        
        begin 
          document = REXML::Document.new("<response>#{xml}</response>")
        rescue REXML::ParseException
          response[:success] = FAILURE
          return response
        end
        # Fetch the errors
        document.root.elements.to_a("Error").each_with_index do |e, i|
          response["error_#{i}".to_sym] = e.text
        end
        
        # Check if completed
        if REXML::XPath.first(document, '//Orders')
          result = Hash.from_xml("<response>#{xml}</response>")
          response[:success] = SUCCESS
          response.merge!(result)
        else
          response[:success] = FAILURE
        end        
        response
      end
      
      def parse_creation_response(xml)
        response = {}
        begin 
          document = REXML::Document.new("<response>#{xml}</response>")
        rescue REXML::ParseException
          response[:success] = FAILURE
          return response
        end
        # Fetch the errors
        document.root.elements.to_a("Error").each_with_index do |e, i|
          response["error_#{i}".to_sym] = e.text
        end
        
        result = Hash.from_xml("<response>#{xml}</response>")
        response[:success] = SUCCESS
        response.merge!(result)
      end
      
      
      
    end
  end
end


