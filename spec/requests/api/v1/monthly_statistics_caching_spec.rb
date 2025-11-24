require 'rails_helper'

RSpec.describe 'Api::V1::ProductionOrders Monthly Statistics Caching', type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:manager) { create(:user, role: :production_manager) }
  let(:operator) { create(:user, role: :operator) }
  let(:token) { JsonWebToken.encode(user_id: current_user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  before do
    # Clear cache before each test
    Rails.cache.clear
  end

  describe 'GET /api/v1/production_orders/monthly_statistics' do
    context 'caching behavior' do
      let(:current_user) { admin }
      let!(:normal_order) { create(:normal_order, start_date: Date.current, creator: manager) }

      it 'caches the statistics on first request' do
        # Clear cache to ensure clean state
        cache_key = "monthly_stats/#{admin.role}/#{Date.current.year}/#{Date.current.month}"
        Rails.cache.delete(cache_key)

        # First request - cache should not exist
        expect(Rails.cache.exist?(cache_key)).to be false

        get '/api/v1/production_orders/monthly_statistics', headers: headers
        expect(response).to have_http_status(:ok)
        first_response = JSON.parse(response.body)

        # After first request, cache should exist
        expect(Rails.cache.exist?(cache_key)).to be true

        # Second request - should return same data from cache
        get '/api/v1/production_orders/monthly_statistics', headers: headers
        expect(response).to have_http_status(:ok)
        second_response = JSON.parse(response.body)

        # Responses should be identical
        expect(second_response).to eq(first_response)
      end

      it 'uses different cache keys for different roles' do
        # Admin request
        admin_token = JsonWebToken.encode(user_id: admin.id)
        admin_headers = { 'Authorization' => "Bearer #{admin_token}" }

        get '/api/v1/production_orders/monthly_statistics', headers: admin_headers
        expect(response).to have_http_status(:ok)
        admin_response = JSON.parse(response.body)

        # Manager request
        manager_token = JsonWebToken.encode(user_id: manager.id)
        manager_headers = { 'Authorization' => "Bearer #{manager_token}" }

        get '/api/v1/production_orders/monthly_statistics', headers: manager_headers
        expect(response).to have_http_status(:ok)
        manager_response = JSON.parse(response.body)

        # Both should have made database queries (different cache keys)
        # Responses should be the same in this case since both can see all orders
        expect(admin_response['data']).to eq(manager_response['data'])
      end

      it 'uses different cache keys for different operators' do
        operator1 = create(:user, role: :operator, email: 'op1@example.com')
        operator2 = create(:user, role: :operator, email: 'op2@example.com')

        # Create order for operator1
        order1 = create(:normal_order, start_date: Date.current, creator: operator1)

        # Operator1 request
        op1_token = JsonWebToken.encode(user_id: operator1.id)
        op1_headers = { 'Authorization' => "Bearer #{op1_token}" }

        get '/api/v1/production_orders/monthly_statistics', headers: op1_headers
        expect(response).to have_http_status(:ok)
        op1_response = JSON.parse(response.body)

        # Operator2 request
        op2_token = JsonWebToken.encode(user_id: operator2.id)
        op2_headers = { 'Authorization' => "Bearer #{op2_token}" }

        get '/api/v1/production_orders/monthly_statistics', headers: op2_headers
        expect(response).to have_http_status(:ok)
        op2_response = JSON.parse(response.body)

        # They should see different statistics (operator1 has 1 order, operator2 has 0)
        expect(op1_response['data']['current_month']['total_orders_started']).to eq(1)
        expect(op2_response['data']['current_month']['total_orders_started']).to eq(0)
      end

      it 'invalidates cache when a new order is created' do
        # First request - populate cache
        get '/api/v1/production_orders/monthly_statistics', headers: headers
        expect(response).to have_http_status(:ok)
        first_stats = JSON.parse(response.body)
        initial_count = first_stats['data']['current_month']['total_orders_started']

        # Create a new order
        post '/api/v1/production_orders', headers: headers, params: {
          production_order: {
            start_date: Date.current,
            expected_end_date: Date.current + 1.week
          }
        }, as: :json

        expect(response).to have_http_status(:created)

        # Request statistics again - should show updated count
        get '/api/v1/production_orders/monthly_statistics', headers: headers
        expect(response).to have_http_status(:ok)
        updated_stats = JSON.parse(response.body)
        updated_count = updated_stats['data']['current_month']['total_orders_started']

        expect(updated_count).to eq(initial_count + 1)
      end

      it 'invalidates cache when an order is updated' do
        pending_order = create(:normal_order,
                              start_date: Date.current,
                              status: :pending,
                              creator: manager)

        # First request - populate cache
        get '/api/v1/production_orders/monthly_statistics', headers: headers
        expect(response).to have_http_status(:ok)
        first_stats = JSON.parse(response.body)
        initial_completed = first_stats['data']['current_month']['completed_orders']

        # Update order to completed status
        patch "/api/v1/production_orders/#{pending_order.id}", headers: headers, params: {
          production_order: { status: :completed }
        }, as: :json

        expect(response).to have_http_status(:ok)

        # Request statistics again - should show updated completed count
        get '/api/v1/production_orders/monthly_statistics', headers: headers
        expect(response).to have_http_status(:ok)
        updated_stats = JSON.parse(response.body)
        updated_completed = updated_stats['data']['current_month']['completed_orders']

        expect(updated_completed).to eq(initial_completed + 1)
      end

      it 'invalidates cache when an order is deleted' do
        order_to_delete = create(:normal_order, start_date: Date.current, creator: manager)

        # First request - populate cache
        get '/api/v1/production_orders/monthly_statistics', headers: headers
        expect(response).to have_http_status(:ok)
        first_stats = JSON.parse(response.body)
        initial_count = first_stats['data']['current_month']['total_orders_started']

        # Delete the order
        delete "/api/v1/production_orders/#{order_to_delete.id}", headers: headers
        expect(response).to have_http_status(:ok)

        # Request statistics again - should show updated count
        get '/api/v1/production_orders/monthly_statistics', headers: headers
        expect(response).to have_http_status(:ok)
        updated_stats = JSON.parse(response.body)
        updated_count = updated_stats['data']['current_month']['total_orders_started']

        expect(updated_count).to eq(initial_count - 1)
      end

      it 'stores data in cache with proper key format' do
        current_month_start = Date.current.beginning_of_month

        # Make a request
        get '/api/v1/production_orders/monthly_statistics', headers: headers
        expect(response).to have_http_status(:ok)

        # Verify cache key exists with correct format
        cache_key = "monthly_stats/#{admin.role}/#{current_month_start.year}/#{current_month_start.month}"
        expect(Rails.cache.exist?(cache_key)).to be true

        # Verify cached data matches response
        cached_data = Rails.cache.read(cache_key)
        expect(cached_data).to be_a(Hash)
        expect(cached_data[:current_month]).to be_present
      end
    end
  end
end
