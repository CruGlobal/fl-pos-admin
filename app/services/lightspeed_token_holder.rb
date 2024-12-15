require 'httparty'
require 'dotenv'
# Load .env.local instead of .env
Dotenv.overload('.env.local')

class LightspeedTokenHolder

  @token = nil
  @refresh_token = nil
  @expires_in = nil
  @token_type = nil

  def token
    @token
  end

  def refresh_token
    @refresh_token
  end

  def expires_in
    @expires_in
  end

  def token_type
    @token_type
  end

  LIGHTSPEED_API_AUTH_ROOT = ENV['LIGHTSPEED_API_AUTH_ROOT']
  LIGHTSPEED_CLIENT_ID = ENV['LIGHTSPEED_CLIENT_ID']
  LIGHTSPEED_CLIENT_SECRET = ENV['LIGHTSPEED_CLIENT_SECRET']

  def initialize(token: nil, refresh_token: nil)
    File.open(Rails.root.join('lightspeed_auth.json').to_s, 'r') do |f|
      auth = JSON.parse(f.read)
      @token = auth['access_token']
      @refresh_token = auth['refresh_token']
    end
    @expires_in = 3600
    @token_type = "Bearer"
  end

  def oauth_token
    @token
  end

  def refresh_oauth_token
    puts "Refreshing Lightspeed API token..."
    url = LIGHTSPEED_API_AUTH_ROOT.dup
    # use httparty to make a post request to the lightspeed auth endpoint
    response = HTTParty.post(url, body: { client_id: LIGHTSPEED_CLIENT_ID, client_secret: LIGHTSPEED_CLIENT_SECRET, grant_type: 'refresh_token', refresh_token: @refresh_token })
    if response.code == 200
      puts "Token refreshed successfully - #{response.body}"
      # write the refreshed response to the file
      File.open(Rails.root.join('lightspeed_auth.json').to_s, 'w') do |f|
        f.write(response.body)
      end
      # parse the response and return the new access_token
      auth = JSON.parse(response.body)
      @token = auth['access_token']
      @refresh_token = auth['refresh_token']
      @token
    else
      # log the error
      Rails.logger.error("Error refreshing token: #{response.code} - #{response.body}")
      false
    end
    @refresh_token
  end
end
