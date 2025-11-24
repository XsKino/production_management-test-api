require 'rails_helper'

RSpec.describe Api::V1::AuthenticationController, type: :controller do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }

  describe 'POST #login' do
    context 'with valid credentials' do
      it 'returns a JWT token and user data' do
        post :login, params: { email: user.email, password: 'password123' }

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['data']['token']).to be_present
        expect(json_response['data']['user']['id']).to eq(user.id)
        expect(json_response['data']['user']['email']).to eq(user.email)
        expect(json_response['data']['user']['name']).to eq(user.name)
        expect(json_response['data']['user']['role']).to eq(user.role)
      end

      it 'token can be decoded to get user_id' do
        post :login, params: { email: user.email, password: 'password123' }

        json_response = JSON.parse(response.body)
        token = json_response['data']['token']

        decoded = JsonWebToken.decode(token)
        expect(decoded[:user_id]).to eq(user.id)
      end
    end

    context 'with invalid email' do
      it 'returns unauthorized error' do
        post :login, params: { email: 'wrong@example.com', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Invalid email or password')
        expect(json_response['code']).to eq('INVALID_CREDENTIALS')
      end
    end

    context 'with invalid password' do
      it 'returns unauthorized error' do
        post :login, params: { email: user.email, password: 'wrongpassword' }

        expect(response).to have_http_status(:unauthorized)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Invalid email or password')
      end
    end
  end

  describe 'POST #logout' do
    it 'returns success message' do
      post :logout

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Logged out successfully')
    end
  end

  describe 'POST #refresh' do
    let(:token) { JsonWebToken.encode(user_id: user.id) }

    context 'with valid token' do
      it 'returns a new JWT token' do
        request.headers['Authorization'] = "Bearer #{token}"

        post :refresh

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['data']['token']).to be_present
        expect(json_response['data']['user']['id']).to eq(user.id)

        # Verify the new token can be decoded and contains correct user_id
        new_token = json_response['data']['token']
        decoded = JsonWebToken.decode(new_token)
        expect(decoded[:user_id]).to eq(user.id)
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized error' do
        request.headers['Authorization'] = "Bearer invalid_token"

        post :refresh

        expect(response).to have_http_status(:unauthorized)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['code']).to eq('INVALID_TOKEN')
      end
    end

    context 'with expired user' do
      it 'returns not found error' do
        deleted_user = create(:user)
        token = JsonWebToken.encode(user_id: deleted_user.id)
        deleted_user.destroy

        request.headers['Authorization'] = "Bearer #{token}"

        post :refresh

        expect(response).to have_http_status(:not_found)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['code']).to eq('USER_NOT_FOUND')
      end
    end
  end
end
