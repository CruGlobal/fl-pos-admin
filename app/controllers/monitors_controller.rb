class MonitorsController < ApplicationController
  #skip_before_action :authenticate_user

  def lb
    render plain: "OK"
  end
end
