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
end
