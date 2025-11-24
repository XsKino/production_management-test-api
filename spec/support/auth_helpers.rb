module AuthHelpers
  def generate_token(user)
    JsonWebToken.encode(user_id: user.id)
  end

  def auth_headers_for(user)
    token = generate_token(user)
    { 'Authorization' => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :controller
  config.include AuthHelpers, type: :request
end
