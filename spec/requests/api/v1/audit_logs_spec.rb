require 'rails_helper'

RSpec.describe 'Api::V1::ProductionOrders Audit Logs', type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:manager) { create(:user, role: :production_manager) }
  let(:operator) { create(:user, role: :operator) }
  let(:token) { JsonWebToken.encode(user_id: current_user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }
  let!(:order) { create(:normal_order, creator: manager) }

  before do
    # Clear any existing audit logs (including the one from order creation)
    OrderAuditLog.destroy_all

    # Create some audit logs manually
    3.times do |i|
      OrderAuditLog.create!(
        production_order: order,
        user: manager,
        action: 'updated',
        change_details: { status: { from: 'pending', to: 'completed' } },
        ip_address: '127.0.0.1',
        user_agent: 'Test Agent',
        created_at: i.days.ago
      )
    end
  end

  describe 'GET /api/v1/production_orders/:id/audit_logs' do
    context 'as admin' do
      let(:current_user) { admin }

      it 'returns audit logs for the order' do
        get "/api/v1/production_orders/#{order.id}/audit_logs", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']).to be_an(Array)
        expect(json['data'].length).to eq(3)
        expect(json['data'].first['action']).to eq('updated')
        expect(json['data'].first['user']).to be_present
        expect(json['data'].first['user']['name']).to eq(manager.name)
      end

      it 'returns logs in descending order by created_at' do
        get "/api/v1/production_orders/#{order.id}/audit_logs", headers: headers

        json = JSON.parse(response.body)
        dates = json['data'].map { |log| Time.parse(log['created_at']) }

        expect(dates).to eq(dates.sort.reverse)
      end

      it 'includes pagination metadata' do
        get "/api/v1/production_orders/#{order.id}/audit_logs", headers: headers

        json = JSON.parse(response.body)

        expect(json['meta']).to be_present
        expect(json['meta']['pagination']).to be_present
        expect(json['meta']['pagination']['total_count']).to eq(3)
      end
    end

    context 'as production manager (creator)' do
      let(:current_user) { manager }

      it 'returns audit logs for their own order' do
        get "/api/v1/production_orders/#{order.id}/audit_logs", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']).to be_an(Array)
        expect(json['data'].length).to eq(3)
      end
    end

    context 'as operator assigned to order' do
      let(:current_user) { operator }

      before do
        create(:order_assignment, user: operator, production_order: order)
      end

      it 'returns audit logs for assigned order' do
        get "/api/v1/production_orders/#{order.id}/audit_logs", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']).to be_an(Array)
        expect(json['data'].length).to eq(3)
      end
    end

    context 'as operator not assigned to order' do
      let(:current_user) { operator }

      it 'returns not found' do
        get "/api/v1/production_orders/#{order.id}/audit_logs", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with pagination' do
      let(:current_user) { admin }

      before do
        # Create more logs
        7.times do |i|
          OrderAuditLog.create!(
            production_order: order,
            user: manager,
            action: 'updated',
            change_details: {},
            ip_address: '127.0.0.1',
            user_agent: 'Test Agent',
            created_at: (i + 3).days.ago
          )
        end
      end

      it 'paginates results' do
        get "/api/v1/production_orders/#{order.id}/audit_logs?page=1&per_page=5", headers: headers

        json = JSON.parse(response.body)

        expect(json['data'].length).to eq(5)
        expect(json['meta']['pagination']['current_page']).to eq(1)
        expect(json['meta']['pagination']['total_count']).to eq(10)
      end
    end
  end
end
