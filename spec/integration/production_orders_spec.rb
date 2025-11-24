require 'rails_helper'

RSpec.describe 'Production Orders API', type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:manager) { create(:user, role: :production_manager) }

  let(:auth_headers) { auth_headers_for(admin) }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }
  let(:headers) { auth_headers.merge(json_headers) }

  describe 'Production Orders CRUD' do
    describe 'GET /api/v1/production_orders' do
      let!(:normal_order) { create(:normal_order, creator: admin) }
      let!(:urgent_order) { create(:urgent_order, creator: admin) }

      it 'returns paginated list of orders' do
        get '/api/v1/production_orders', headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].length).to eq(2)
        expect(json_response['meta']['pagination']).to be_present
      end

      it 'filters orders by status' do
        normal_order.update!(status: :completed)
        
        get '/api/v1/production_orders', 
            headers: headers,
            params: { q: { status_eq: 'pending' } }
        
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(1)
        expect(json_response['data'].first['status']).to eq('pending')
      end

      it 'filters orders by date range' do
        future_date = 1.month.from_now
        normal_order.update!(start_date: future_date)
        
        get '/api/v1/production_orders',
            headers: headers,
            params: { 
              q: { 
                start_date_gteq: future_date.beginning_of_month,
                start_date_lteq: future_date.end_of_month
              } 
            }
        
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(1)
      end

      it 'paginates results correctly' do
        # Create more orders to test pagination
        8.times { create(:normal_order, creator: admin) }
        
        get '/api/v1/production_orders',
            headers: headers,
            params: { page: 1, per_page: 5 }
        
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(5)
        expect(json_response['meta']['pagination']['total_count']).to eq(10)
        expect(json_response['meta']['pagination']['total_pages']).to eq(2)
      end
    end

    describe 'POST /api/v1/production_orders' do
      let(:order_params) do
        {
          production_order: {
            start_date: Date.current,
            expected_end_date: 1.week.from_now,
            status: 'pending',
            tasks_attributes: [
              {
                description: 'Initial setup',
                expected_end_date: 2.days.from_now,
                status: 'pending'
              },
              {
                description: 'Testing phase',
                expected_end_date: 5.days.from_now,
                status: 'pending'
              }
            ]
          },
          user_ids: [manager.id]
        }
      end

      it 'creates order with nested tasks and assignments' do
        expect {
          post '/api/v1/production_orders',
               headers: headers,
               params: order_params.to_json
        }.to change(ProductionOrder, :count).by(1)
         .and change(Task, :count).by(2)
         .and change(OrderAssignment, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['success']).to be true
        
        order_data = json_response['data']
        expect(order_data['order_number']).to eq(1)
        expect(order_data['tasks'].length).to eq(2)
        expect(order_data['assigned_users'].length).to eq(1)
      end

      it 'creates urgent order with deadline' do
        urgent_params = order_params.deep_merge(
          production_order: {
            type: 'UrgentOrder',
            deadline: 3.days.from_now
          }
        )

        post '/api/v1/production_orders',
             headers: headers,
             params: urgent_params.to_json

        expect(response).to have_http_status(:created)
        expect(json_response['data']['type']).to eq('UrgentOrder')
        expect(json_response['data']['deadline']).to be_present
      end

      it 'returns validation errors for invalid data' do
        invalid_params = {
          production_order: {
            start_date: nil,
            expected_end_date: nil,
            tasks_attributes: [
              {
                description: nil,
                expected_end_date: nil
              }
            ]
          }
        }

        post '/api/v1/production_orders',
             headers: headers,
             params: invalid_params.to_json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['success']).to be false
        expect(json_response['errors']).to be_present
      end
    end

    describe 'GET /api/v1/production_orders/:id' do
      let(:order) { create(:normal_order, creator: admin) }
      let!(:task1) { create(:task, production_order: order, status: :pending) }
      let!(:task2) { create(:task, production_order: order, status: :completed) }

      it 'returns order with all tasks and summary' do
        get "/api/v1/production_orders/#{order.id}", headers: headers

        expect(response).to have_http_status(:ok)
        
        order_data = json_response['data']
        expect(order_data['id']).to eq(order.id)
        expect(order_data['tasks'].length).to eq(2)
        expect(order_data['tasks_summary']['total']).to eq(2)
        expect(order_data['tasks_summary']['pending']).to eq(1)
        expect(order_data['tasks_summary']['completed']).to eq(1)
        expect(order_data['tasks_summary']['completion_percentage']).to eq(50.0)
      end
    end
  end

  describe 'Advanced API Endpoints' do
    describe 'GET /api/v1/production_orders/monthly_statistics' do
      let!(:normal_order) { create(:normal_order, creator: admin, start_date: Date.current) }
      let!(:urgent_order) { create(:urgent_order, creator: admin, deadline: Date.current.end_of_month) }
      let!(:completed_order) { create(:normal_order, creator: admin, status: :completed) }

      it 'returns accurate monthly statistics' do
        get '/api/v1/production_orders/monthly_statistics', headers: headers

        expect(response).to have_http_status(:ok)

        stats = json_response['data']['current_month']
        expect(stats['normal_orders_starting']).to eq(2) # normal_order + completed_order
        expect(stats['urgent_orders_with_deadline']).to eq(1)
        expect(stats['total_orders_started']).to eq(3)
      end
    end

    describe 'GET /api/v1/production_orders/urgent_orders_report' do
      let!(:urgent_order) { create(:urgent_order, creator: admin) }
      let!(:pending_task) { create(:task, production_order: urgent_order, status: :pending) }
      let!(:completed_task) { create(:task, production_order: urgent_order, status: :completed) }

      it 'returns urgent orders with detailed task statistics' do
        get '/api/v1/production_orders/urgent_orders_report', headers: headers

        expect(response).to have_http_status(:ok)
        
        order_data = json_response['data'].first
        expect(order_data['type']).to eq('UrgentOrder')
        expect(order_data['pending_tasks_count']).to eq(1)
        expect(order_data['completed_tasks_count']).to eq(1)
        expect(order_data['total_tasks_count']).to eq(2)
        expect(order_data['completion_percentage']).to eq(50.0)
      end
    end

    describe 'GET /api/v1/production_orders/urgent_with_expired_tasks' do
      let!(:urgent_order) { create(:urgent_order, creator: admin) }
      let!(:expired_task) { 
        create(:task, 
               production_order: urgent_order, 
               status: :pending, 
               expected_end_date: 1.day.ago) 
      }
      let!(:normal_task) { 
        create(:task, 
               production_order: urgent_order, 
               status: :pending, 
               expected_end_date: 1.day.from_now) 
      }

      it 'returns urgent orders with expired pending tasks' do
        get '/api/v1/production_orders/urgent_with_expired_tasks', headers: headers

        expect(response).to have_http_status(:ok)
        
        order_data = json_response['data'].first
        expect(order_data['type']).to eq('UrgentOrder')
        expect(order_data['expired_tasks_count']).to eq(1)
        expect(order_data['expired_tasks'].first['id']).to eq(expired_task.id)
        expect(order_data['expired_tasks'].first['is_overdue']).to be true
      end
    end
  end

  describe 'Task Management' do
    let(:order) { create(:normal_order, creator: admin) }

    describe 'POST /api/v1/production_orders/:production_order_id/tasks' do
      let(:task_params) do
        {
          task: {
            description: 'New task',
            expected_end_date: 3.days.from_now,
            status: 'pending'
          }
        }
      end

      it 'creates new task for order' do
        expect {
          post "/api/v1/production_orders/#{order.id}/tasks",
               headers: headers,
               params: task_params,
               as: :json
        }.to change(Task, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['data']['description']).to eq('New task')

        order.reload
        expect(order.tasks.count).to eq(1)
      end
    end

    describe 'PATCH /api/v1/production_orders/:production_order_id/tasks/:id/complete' do
      let!(:task) { create(:task, production_order: order, status: :pending) }

      it 'marks task as completed' do
        patch "/api/v1/production_orders/#{order.id}/tasks/#{task.id}/complete",
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['status']).to eq('completed')
        
        task.reload
        expect(task.completed?).to be true
      end
    end
  end

  private

  def json_response
    @json_response ||= JSON.parse(response.body)
  end
end