class LightspeedauthController < ApplicationController
  def index
    # Get the code from the request
    code = params[:code]
    # Get the access token
    token = Lightspeed::Auth.get_access_token(code)
    # write the current response to the file system at APP_ROOT/lightspeed_auth.json
    File.open("#{Rails.root}/lightspeed_auth.json", 'w') do |f|
      f.write(token.to_json)
    end
    # Redirect to the home page
    redirect_to root_path
  end
end
