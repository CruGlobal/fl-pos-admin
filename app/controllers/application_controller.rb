class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user

  protected

  def signed_in?
    session[:id_token].present?
  end

  def authenticate_user
    unless signed_in?
      redirect_to new_session_path
    end
  end
end
