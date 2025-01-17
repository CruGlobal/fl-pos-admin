require "rails_helper"

xdescribe LightspeedTokenHolder do
  it("should initialize with a token and refresh token") do
    token_holder = LightspeedTokenHolder.new
    expect(token_holder.token).not_to be_nil
    expect(token_holder.refresh_token).not_to be_nil
  end

  it("should refresh the token") do
    token_holder = LightspeedTokenHolder.new
    old_token = token_holder.token
    token_holder.refresh_oauth_token
    expect(token_holder.token).not_to eq(old_token)
    puts "Old token: #{old_token}"
    puts "New token: #{token_holder.token}"
  end
end
