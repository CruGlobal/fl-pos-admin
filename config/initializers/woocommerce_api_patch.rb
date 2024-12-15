# require 'woocommerce_api/lib/woocommerce_api'
# require 'uri'
# 
# module WooCommerce
#   class API.class_eval do
#     def add_query_params endpoint, data
#       return endpoint if data.nil? || data.empty?
# 
#       endpoint += "?" unless endpoint.include? "?"
#       endpoint += "&" unless endpoint.end_with? "?"
#       endpoint + URI.escape(flatten_hash(data).join("&"))
#     end
#   end
# end
