module WooCommerce
  class API
    def add_query_params endpoint, data
      return endpoint if data.nil? || data.empty?

      endpoint += "?" unless endpoint.include? "?"
      endpoint += "&" unless endpoint.end_with? "?"
      qs = URI::DEFAULT_PARSER.escape(data.to_query)
      endpoint + qs
    end
  end

  class OAuth
    def get_oauth_url
      params = {}
      url = @url

      if url.include?("?")
        parsed_url = URI::parse(url)
        CGI::parse(parsed_url.query).each do |key, value|
          params[key] = value[0]
        end
        params = Hash[params.sort]

        url = parsed_url.to_s.gsub(/\?.*/, "")
      end

      nonce_lifetime = 15 * 60 # Woocommerce keeps nonces for 15 minutes

      params["oauth_consumer_key"] = @consumer_key
      params["oauth_nonce"] = Digest::SHA1.hexdigest((Time.new.to_f % nonce_lifetime + (Process.pid * nonce_lifetime)).to_s)
      params["oauth_signature_method"] = @signature_method
      params["oauth_timestamp"] = Time.new.to_i
      params["oauth_signature"] = CGI::escape(generate_oauth_signature(params, url))

      query_string = URI::DEFAULT_PARSER.escape(params.map{|key, value| "#{key}=#{value}"}.join("&"))

      "#{url}?#{query_string}"
    end
  end
end
