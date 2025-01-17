class LightspeedinitController < ApplicationController
  # Redirect to lightspeed auth login page
  LIGHTSPEED_AUTH_REQUEST_URL = ENV["LIGHTSPEED_AUTH_REQUEST_URL"]

  def index
    url = LIGHTSPEED_AUTH_REQUEST_URL.dup
    url.sub! "CLIENT_ID", ENV["LIGHTSPEED_CLIENT_ID"]
    redirect_to url, allow_other_host: true
  end
end
