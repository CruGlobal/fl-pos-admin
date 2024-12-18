module WooCommerce
  class API
    def add_query_params endpoint, data
      return endpoint if data.nil? || data.empty?

      endpoint += "?" unless endpoint.include? "?"
      endpoint += "&" unless endpoint.end_with? "?"
      qs = URI::Parser.new.escape(data.to_query)
      endpoint = endpoint + qs
      endpoint
    end
  end
end
