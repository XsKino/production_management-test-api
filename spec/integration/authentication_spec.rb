require 'rails_helper'

RSpec.describe 'Authentication API', type: :request do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123', role: :admin) }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  describe 'POST /api/v1/auth/login' do
    it 'authenticates user and returns JWT token' do
      post '/api/v1/auth/login',
           params: { email: user.email, password: 'password123' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['token']).to be_present
      expect(json_response['data']['user']['email']).to eq(user.email)
    end

    it 'returns error with invalid credentials' do
      post '/api/v1/auth/login',
           params: { email: user.email, password: 'wrongpassword' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Protected endpoints with JWT' do
    let(:token) { JsonWebToken.encode(user_id: user.id) }
    let(:auth_headers) { json_headers.merge({ 'Authorization' => "Bearer #{token}" }) }

    context 'with valid token' do
      it 'allows access to protected endpoint' do
        get '/api/v1/production_orders', headers: auth_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'without token' do
      it 'denies access to protected endpoint' do
        get '/api/v1/production_orders', headers: json_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      it 'denies access to protected endpoint' do
        invalid_headers = json_headers.merge({ 'Authorization' => 'Bearer invalid_token' })

        get '/api/v1/production_orders', headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/auth/refresh' do
    let(:token) { JsonWebToken.encode(user_id: user.id) }

    it 'refreshes JWT token' do
      post '/api/v1/auth/refresh',
           headers: { 'Authorization' => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response['data']['token']).to be_present

      # Verify the new token can be decoded and contains correct user_id
      new_token = json_response['data']['token']
      decoded = JsonWebToken.decode(new_token)
      expect(decoded[:user_id]).to eq(user.id)
    end
  end

  describe 'POST /api/v1/auth/logout' do
    it 'logs out successfully' do
      post '/api/v1/auth/logout'

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response['message']).to eq('Logged out successfully')
    end
  end
end
