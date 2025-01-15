class LightspeedauthController < ApplicationController
  def index
    lth = LightspeedTokenHolder.new
    # Get the code from the request
    code = params[:code]
    # Get the access token
    token = lth.trade_access_token(code)
    # write the current response to the file system at APP_ROOT/lightspeed_auth.json
    File.open("#{Rails.root}/lightspeed_auth.json", "w") do |f|
      Rails.logger.info "Writing token to file... #{token}"
      f.write(token)
    end
    # Redirect to the home page
    redirect_to root_path
  end
end
