require "rails_helper"

RSpec.describe SessionsController, type: :controller do
  describe "GET #destroy" do
    it "clears the session and ends the Okta session, returning to the registered logout URL" do
      session[:id_token] = "fake-token"

      get :destroy

      expect(session[:id_token]).to be_nil
      expect(response).to redirect_to(
        "#{ENV.fetch("OKTA_ISSUER")}/v1/logout?id_token_hint=fake-token&post_logout_redirect_uri=http%3A%2F%2Ftest.host%2F"
      )
    end

    it "goes to the home page when there is no Okta session to end" do
      get :destroy

      expect(response).to redirect_to(root_path)
    end
  end
end
