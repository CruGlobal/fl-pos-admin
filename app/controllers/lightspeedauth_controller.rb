class LightspeedauthController < ApplicationController
  def index
    lth = LightspeedTokenHolder.new
    # Get the code from the request
    code = params[:code]
    # Get the access token
    token = lth.trade_access_token(code)
    # write the current response to cache
    Rails.cache.write("lightspeed_auth", token)
    # Redirect to the home page
    redirect_to root_path
  end
end
