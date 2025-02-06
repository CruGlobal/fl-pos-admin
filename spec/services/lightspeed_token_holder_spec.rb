require "rails_helper"

describe LightspeedTokenHolder do
  before do
    Rails.cache.write("lightspeed_auth", {token_type: "Bearer", expires_in: 3600, access_token: "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6IlJUX09BVVRIMl8yMDI0XzA3XzIyIn0.eyJqdGkiOiI4OTEzMDkxNzE3ZjdiZTEzNGE3ZDU2YTE0MzczMDA3NDlhZDQyMWU3ZDQ4ZGM3NjE3Mzg0OTk5Nzg1YjI2N2JmMzRkNTI5ZmJjYmVjNWIyZCIsImlzcyI6Imh0dHBzOi8vY2xvdWQubGlnaHRzcGVlZGFwcC5jb20iLCJhdWQiOiI4Zjg1OTM0MTJlOWM1ZWFjNjEwZjRhZjQ0NTk0NTdjNGM0MjkxYWZhOTlmZDRhNjNkZDQxNTNiODk0ODQxMjk5Iiwic3ViIjoiMTYxNTMxNiIsImFjY3QiOiIyNzAxMCIsInNjb3BlIjoiZW1wbG95ZWU6YWxsIiwiaWF0IjoxNzM3MDU2NDk1LjQ0MTAyMiwibmJmIjoxNzM3MDU2NDk1LjQ0MTAyMiwiZXhwIjoxNzM3MDYwMDk1LjQxODY0Nn0.ktoLAcZKvggrhiPOqRhMrBBCdI5m0MSjqZBxmJfIwxwgaWf8I_BqeDjfD4IkFHxkiOZqblelY1OjUqEpfShLuezDSWvZGXFLyEL74nZDjZ3LzR8mnXUwm1mORicR_B676ra6TTFksCfOz4Uf74aAs01AIWI54qoRz7HP59gaJLEprKdkLd5IzHoK9SmWPrXDWdm9IUCTNywNijsjkKmQolHJFXc_MlFbGi9cXnClzsKsSwkpRwmGZEt6b-TUlKjy91gdOjLASqkwzUF7_ntylBqY3Z-CszAN2LdgY4yL7_QACq-mpBvwHJJuYDxvtHkK0aGLGEQ6ah_ASUURHwKT4A", refresh_token: "def50200250b783f1086d8057eaf03b5d4289623c477709e9cdd99d2de8e27ef96e0ce606f02419289c39e31fed31cb7acb25f3e1edb6199ac16df25ea0c24d6ad31ddfeea5b91e3058b25d924aad5b2b9ac03d723324489ac7ed91ff79d354ed5a2ce258a05bf0747c3a18a9768497e5e603fcb258b34813b14b4e1b50cac0c0d0d7ca80b1581da9cf29bc1e2023f40d680acd5199244a8b90fb89b23fa3d7a03326b78bace5a389760a054a374f37699fca4945a1b4fe43686dbb3aa5e09327e39d720b89eb39f3a39f265e43c734ea292d3be5437fccc3faf735a8395e15336cc27ad3e54531e8a83326e2f04a62b73b157c71c4a942f1d8108a625c11f90020531129fe39f78882ac094acba2eb2f8cb33af476731a1c53c601fca6ece4f31ff0ca29c152df583df67d1a63159302fe635a2b25e92d0a105c6a1f6b3ede938d2d9c02a7d2a2d4bf6b81d4b54a1c00a9064bba645536f7bf48b50efecd46df34a34018da4c1bf14eb4c32c22ec2d0ff01fd6bd9d42e9eb13f92d644b0819451550431a380563122c8b6c7c0f30f56243a486659de9809b8a7328d77ee2e4f0448ffd9cb66c12be4f5be460118ae27c18844810f32"}.to_json)
  end

  it("should initialize with a token and refresh token") do
    token_holder = LightspeedTokenHolder.new
    expect(token_holder.token).not_to be_nil
    expect(token_holder.refresh_token).not_to be_nil
  end

  it("should refresh the token") do
    stub_request(:post, "https://api.lightspeedapp.com/auth/oauth/token").to_return(status: 200, body: {token_type: "Bearer", expires_in: 3600, access_token: "new_token", refresh_token: "new_refresh_token"}.to_json)
    token_holder = LightspeedTokenHolder.new
    old_token = token_holder.token
    token_holder.refresh_oauth_token
    expect(token_holder.token).not_to eq(old_token)
    puts "Old token: #{old_token}"
    puts "New token: #{token_holder.token}"
  end
end
