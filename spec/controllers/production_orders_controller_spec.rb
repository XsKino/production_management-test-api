require 'rails_helper'

RSpec.describe Api::V1::ProductionOrdersController, type: :controller do
  let(:admin) { create(:user, role: :admin) }
  let(:manager) { create(:user, role: :production_manager) }
  let(:operator) { create(:user, role: :operator) }
  
  before do
    # Simple authentication for testing
    request.headers['Authorization'] = "Bearer #{admin.id}"
  end

  describe 'GET #index' do
    let!(:normal_order) { create(:normal_order, creator: admin) }
    let!(:urgent_order) { create(:urgent_order, creator: admin) }

    it 'returns all production orders' do
      get :index
      
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(2)
    end

    it 'filters by order type' do
      get :index, params: { q: { type_eq: 'NormalOrder' } }
      
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first['type']).to eq('NormalOrder')
    end

    it 'includes pagination metadata' do
      get :index

      json_response = JSON.parse(response.body)
      expect(json_response['meta']['pagination']).to include(
        'current_page',
        'total_pages',
        'total_count',
        'per_page'
      )
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        production_order: {
          start_date: Date.current,
          expected_end_date: 1.week.from_now,
          status: 'pending',
          tasks_attributes: [
            {
              description: 'Task 1',
              expected_end_date: 2.days.from_now,
              status: 'pending'
            }
          ]
        }
      }
    end

    it 'creates a normal order with tasks' do
      expect {
        post :create, params: valid_params
      }.to change(ProductionOrder, :count).by(1)
        .and change(Task, :count).by(1)

      expect(response).to have_http_status(:created)

      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['type']).to eq('NormalOrder')
      expect(json_response['data']['tasks']).to be_an(Array)
    end

    it 'creates an urgent order when type is specified' do
      urgent_params = valid_params.deep_merge(
        production_order: { 
          type: 'UrgentOrder',
          deadline: 1.week.from_now 
        }
      )

      post :create, params: urgent_params
      
      expect(response).to have_http_status(:created)
      
      json_response = JSON.parse(response.body)
      expect(json_response['data']['type']).to eq('UrgentOrder')
      expect(json_response['data']['deadline']).to be_present
    end

    it 'returns validation errors for invalid data' do
      invalid_params = {
        production_order: {
          start_date: nil,
          expected_end_date: nil
        }
      }

      post :create, params: invalid_params
      
      expect(response).to have_http_status(:unprocessable_content)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be false
      expect(json_response['errors']).to be_an(Array)
    end
  end

  describe 'GET #show' do
    let!(:order) { create(:normal_order, creator: admin) }
    let!(:task) { create(:task, production_order: order) }

    it 'returns order with tasks' do
      get :show, params: { id: order.id }
      
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['id']).to eq(order.id)
      expect(json_response['data']['tasks']).to be_an(Array)
      expect(json_response['data']['tasks_summary']).to be_present
    end

    it 'returns 404 for non-existent order' do
      get :show, params: { id: 99999 }
      
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    let!(:order) { create(:normal_order, creator: admin) }

    it 'updates order successfully' do
      new_date = 2.weeks.from_now
      
      patch :update, params: { 
        id: order.id, 
        production_order: { expected_end_date: new_date } 
      }
      
      expect(response).to have_http_status(:ok)
      
      order.reload
      expect(order.expected_end_date.to_date).to eq(new_date.to_date)
    end
  end

  describe 'DELETE #destroy' do
    let!(:order) { create(:normal_order, creator: admin) }

    it 'deletes order successfully' do
      expect {
        delete :destroy, params: { id: order.id }
      }.to change(ProductionOrder, :count).by(-1)
      
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #monthly_statistics' do
    let!(:normal_order) { create(:normal_order, creator: admin, start_date: Date.current) }
    let!(:urgent_order) { create(:urgent_order, creator: admin, deadline: Date.current + 2.weeks) }

    it 'returns current month statistics' do
      get :monthly_statistics
      
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      stats = json_response['data']['current_month']
      
      expect(stats).to include(
        'normal_orders_starting',
        'urgent_orders_with_deadline',
        'total_orders_started',
        'completed_orders'
      )
    end
  end

  describe 'GET #urgent_orders_report' do
    let!(:urgent_order) { create(:urgent_order, creator: admin) }
    let!(:task1) { create(:task, production_order: urgent_order, status: :pending) }
    let!(:task2) { create(:task, production_order: urgent_order, status: :completed) }

    it 'returns urgent orders with task statistics' do
      get :urgent_orders_report
      
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      order_data = json_response['data'].first
      
      expect(order_data).to include(
        'pending_tasks_count',
        'completed_tasks_count',
        'total_tasks_count',
        'completion_percentage'
      )
    end
  end
end