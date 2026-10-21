require "rails_helper"

RSpec.describe "layouts/application", type: :view do
  it "loads the logout link as a full page so the browser can follow the redirect to Okta" do
    render template: "layouts/application"

    assert_select "a[href='/logout'][data-turbo='false']"
  end
end
