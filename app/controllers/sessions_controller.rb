class SessionsController < ApplicationController
  skip_before_action :authenticate_user
  def new
    redirect_to root_path if signed_in?
  end

  def create
    unless okta_signed_in?
      redirect_to new_session_path,
                  flash: {error: "Sorry, the okta login failed."}
      return
    end

    session[:id_token] = omniauth.dig("extra", "id_token")
    session[:omniauth_hash] = omniauth
    redirect_to root_path
  end

  def destroy
    id_token = session[:id_token]
    session.clear
    if id_token.present?
      redirect_to "#{ENV.fetch("OKTA_ISSUER")}/v1/logout?id_token_hint=#{id_token}&post_logout_redirect_uri=#{request.base_url}", allow_other_host: true
    else
      redirect_to root_path
    end
  end

  private

  def okta_signed_in?
    omniauth&.extra&.raw_info&.email.present?
  end

  def omniauth
    @omniauth ||= request.env["omniauth.auth"]
  end
end
