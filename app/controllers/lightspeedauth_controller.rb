class LightspeedauthController < ApplicationController
  def index
    lth = LightspeedTokenHolder.new
    # Get the code from the request
    code = params[:code]
    # Get the access token
    token = lth.trade_access_token(code)
    # write the current response to cache
    if Rails.env.development? || Rails.env.test?
      File.write("#{Rails.root}/lightspeed_auth.json", token)
    else
      Rails.cache.write("lightspeed_auth", token)
    end
    # Redirect to the home page
    redirect_to root_path
  end
end
