require "httparty"

class LightspeedTokenHolder
  attr_reader :token
  attr_reader :refresh_token
  attr_reader :expires_in
  attr_reader :token_type

  def initialize(token: nil, refresh_token: nil)
    raw = Rails.cache.read("lightspeed_auth")
    if raw
      auth = JSON.parse(raw)
      @token = auth["access_token"]
      @refresh_token = auth["refresh_token"]
    else
      Rails.logger.info "No lightspeed token found. Must reauthenticate."
    end
    @expires_in = 3600
    @token_type = "Bearer"
  end

  def trade_access_token(code)
    Rails.logger.info "Getting Lightspeed API token..."
    url = ENV["LIGHTSPEED_API_AUTH_ROOT"]
    # use httparty to make a post request to the lightspeed auth endpoint
    response = HTTParty.post(url, body: {
      client_id: ENV["LIGHTSPEED_CLIENT_ID"],
      client_secret: ENV["LIGHTSPEED_CLIENT_SECRET"],
      grant_type: "authorization_code",
      code: code
    })
    if response.code == 200
      response.body
    else
      # log the error
      Rails.logger.error("Error retrieving token: #{response.code} - #{response.body}")
      false
    end
  end

  def oauth_token
    @token
  end

  def refresh_oauth_token
    Rails.logger.info "Refreshing Lightspeed API token..."
    url = ENV["LIGHTSPEED_API_AUTH_ROOT"]
    # use httparty to make a post request to the lightspeed auth endpoint
    response = HTTParty.post(url, body: {client_id: ENV["LIGHTSPEED_CLIENT_ID"], client_secret: ENV["LIGHTSPEED_CLIENT_SECRET"], grant_type: "refresh_token", refresh_token: @refresh_token})
    if response.code == 200
      Rails.logger.info "Token refreshed successfully - #{response.body}"
      # write the refreshed response to cache
      Rails.cache.write("lightspeed_auth", response.body)
      # parse the response and return the new access_token
      auth = JSON.parse(response.body)
      @token = auth["access_token"]
      @refresh_token = auth["refresh_token"]
      @token
    else
      # log the error
      Rails.logger.error("Error refreshing token: #{response.code} - #{response.body}")
      false
    end
    @refresh_token
  end
end
