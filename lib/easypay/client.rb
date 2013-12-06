module Easypay
  class Client

    EASYPAY_SERVICE_URL = Rails.env.production? ? "www.easypay.pt" : "test.easypay.pt"

    def initialize *params
      if params.first.is_a?(Hash)
        hash_options = params.first
        @easypay_cin = hash_options[:easypay_cin] || Easypay::Engine.config.cin
        @easypay_user = hash_options[:easypay_user] || Easypay::Engine.config.user
        @easypay_entity = hash_options[:easypay_entity] || Easypay::Engine.config.entity
        @easypay_code = hash_options[:easypay_code] || Easypay::Engine.config.code
        @easypay_ref_type = hash_options[:easypay_ref_type] || "auto"
        @easypay_country = hash_options[:easypay_country] || "PT"
        @easypay_type = hash_options[:easypay_type] || nil
      elsif params.first
        puts "* warning: the method Easypay::Client.new(ep_cin, ep_user, ep_entity) is deprecated, use Easypay::Client.new(:easypay_cin => 'cin', :easypay_user => 'user', :easypay_entity => 'entity')"
        @easypay_cin = params.shift || Easypay::Engine.config.cin
        @easypay_user = params.shift || Easypay::Engine.config.user
        @easypay_entity = params.shift || Easypay::Engine.config.entity
        @easypay_code = params.shift || Easypay::Engine.config.code
        @easypay_ref_type = params.shift || "auto"
        @easypay_country = params.shift || "PT"
      else
        @easypay_cin = Easypay::Engine.config.cin
        @easypay_user = Easypay::Engine.config.user
        @easypay_entity = Easypay::Engine.config.entity
        @easypay_code = Easypay::Engine.config.code
        @easypay_ref_type = "auto"
        @easypay_country = "PT"
      end
    end

    # API methods
    def modify_payment_reference(object, action)
      get "00BG",
        :ep_ref => object.ep_reference,
        :ep_delete => action.match("delete") ? "yes" : "",
        :t_value => object.ep_value,
        :o_name =>  object.o_name.nil? ? "" : URI.escape(object.o_name),
        :o_description => object.o_description.nil? ? "" : URI.escape(object.o_description),
        :o_obs => object.o_obs.nil? ? "" : URI.escape(object.o_obs),
        :o_mobile => object.o_mobile.nil? ? "" : URI.escape(object.o_mobile),
        :o_email => object.o_email.nil? ? "" : URI.escape(object.o_email)
    end

    def create_reference(object)
      result = get "01BG",
        :t_key => object.ep_key,
        :t_value => object.ep_value,
        :ep_language => object.ep_language.upcase,
        :o_name =>  object.o_name.nil? ? "" : URI.escape(object.o_name),
        :o_description => object.o_description.nil? ? "" : URI.escape(object.o_description),
        :o_obs => object.o_obs.nil? ? "" : URI.escape(object.o_obs),
        :o_mobile => object.o_mobile.nil? ? "" : URI.escape(object.o_mobile),
        :o_email => object.o_email.nil? ? "" : URI.escape(object.o_email),
        :ep_type => @easypay_type
      return result["getautoMB"]
    end

    def get_payment_detail(ep_key, ep_doc)
      get "03AG",
        :ep_key => ep_key,
        :ep_doc => ep_doc
    end

    def get_payment_list(type="last", detail=10, format="xml")
      get "040BG1",
          :o_list_type => type,
          :o_ini => detail,
          :type => format
    end

    def request_payment(entity, reference, value, identifier)
      get "05AG",
          :e => entity,
          :r => reference,
          :v => value,
          :k => identifier
          # :ep_k1 => identifier,
          # :rec => "yes",
          # :ep_key_rec => uid
    end


    protected

    def create_http
      if Rails.env.production?
          http = Net::HTTP.new(EASYPAY_SERVICE_URL, 443)
          http.use_ssl = true
      else
          http = Net::HTTP.new(EASYPAY_SERVICE_URL)
      end

      http
    end

    def process_args(current_args)
      current_args[:ep_cin] ||= @easypay_cin
      current_args[:ep_user] ||= @easypay_user
      current_args[:ep_entity] ||= @easypay_entity
      current_args[:ep_ref_type] ||= @easypay_ref_type
      current_args[:ep_country] ||= @easypay_country
      current_args[:s_code] ||= @easypay_code if current_args[:s_code].nil? and !Rails.env.production?
      current_args[:ep_test] = "ok" if current_args[:ep_test].nil? and !Rails.env.production?

      return current_args
    end

    def build_url(service_name, args)
      if service_name.match("^0").nil?
        url = "/_s/_#{service_name}.php?"
      else
        url = "/_s/api_easypay_#{service_name}.php?"
      end

      process_args(args).each do |key, value|
        url += "#{key.to_s}=#{value.to_s}&" if value and value.present?
      end

      return url.chop
    end

    def get(service_name, args)
      begin
        url = build_url(service_name, args)

        response = create_http.get(url, nil)

        result = { :endpoint => EASYPAY_SERVICE_URL, :url => url, :raw => response.body }

        Log.create(:request_type => "Request", :request_url => "#{EASYPAY_SERVICE_URL}#{url}", :raw => response.body)

        return parse_content(result)

      rescue Exception => ex
        return { :success => false, :ep_message => ex.message }
      end
    end

    def parse_content(result)
      doc = Nokogiri::XML(result[:raw])
      data = Hash.from_xml(doc.to_xml).to_json
      return JSON.parse(data)
    end
  end
end
