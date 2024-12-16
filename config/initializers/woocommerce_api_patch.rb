module WooCommerce
  class API
    def add_query_params endpoint, data
      return endpoint if data.nil? || data.empty?

      endpoint += "?" unless endpoint.include? "?"
      endpoint += "&" unless endpoint.end_with? "?"
      endpoint + CGI.escape(flatten_hash(data).join("&"))
    end
  end
end
