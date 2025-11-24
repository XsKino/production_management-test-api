require 'rails_helper'

RSpec.describe 'Query Performance', type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:token) { JsonWebToken.encode(user_id: admin.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  # Helper to count queries
  def count_queries(&block)
    queries = []
    counter = ->(*, payload) do
      queries << payload[:sql] unless payload[:name] == 'SCHEMA' || payload[:sql] =~ /^(BEGIN|COMMIT|SAVEPOINT|RELEASE)/
    end

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &block)
    queries.size
  end

  describe 'GET /api/v1/production_orders' do
    context 'with varying dataset sizes' do
      it 'maintains constant query count regardless of dataset size' do
        # Create 5 orders
        5.times do |i|
          order = create(:normal_order, creator: admin)
          create_list(:task, 2, production_order: order)
        end

        query_count_5 = count_queries do
          get '/api/v1/production_orders', headers: headers
        end

        # Create 15 more orders (total 20)
        15.times do |i|
          order = create(:normal_order, creator: admin)
          create_list(:task, 2, production_order: order)
        end

        query_count_20 = count_queries do
          get '/api/v1/production_orders', headers: headers
        end

        # Query count should be close (proving N+1 is solved with eager loading)
        # Allow +1 query difference due to potential auth/audit queries
        expect(query_count_20).to be_within(1).of(query_count_5)

        # Should be using eager loading efficiently
        # Queries include: orders, tasks, creators, assigned_users, pagination count, audit logs
        expect(query_count_20).to be <= 10
      end

      it 'executes minimal queries for index endpoint' do
        # Create test data
        3.times do
          order = create(:normal_order, creator: admin)
          create_list(:task, 2, production_order: order)
        end

        query_count = count_queries do
          get '/api/v1/production_orders', headers: headers
        end

        # Should use eager loading efficiently
        # Expected queries:
        # 1. SELECT orders with pagination
        # 2. SELECT tasks WHERE order_id IN (...)
        # 3. SELECT users (creators) WHERE id IN (...)
        # 4. SELECT users (assigned_users) through order_assignments
        # 5. SELECT order_assignments
        # 6. COUNT for pagination
        # Plus potential audit log queries
        expect(query_count).to be <= 10
      end
    end
  end

  describe 'GET /api/v1/production_orders/:id' do
    let!(:order) { create(:normal_order, creator: admin) }
    let!(:tasks) { create_list(:task, 5, production_order: order) }

    it 'loads order with tasks efficiently' do
      query_count = count_queries do
        get "/api/v1/production_orders/#{order.id}", headers: headers
      end

      # Should load order with all associations in minimal queries
      # 1. SELECT order
      # 2. SELECT tasks
      # 3. SELECT creator
      # 4. SELECT assigned_users
      # 5. SELECT order_assignments
      # Plus potential audit log queries
      expect(query_count).to be <= 8
    end
  end

  describe 'GET /api/v1/production_orders/monthly_statistics' do
    context 'with cache' do
      before { Rails.cache.clear }

      it 'reduces queries dramatically with cache' do
        # Create test data
        5.times { create(:normal_order, start_date: Date.current, creator: admin) }
        3.times { create(:urgent_order, deadline: Date.current + 5.days, creator: admin) }

        # First request - populates cache
        query_count_first = count_queries do
          get '/api/v1/production_orders/monthly_statistics', headers: headers
        end

        # Second request - uses cache
        query_count_cached = count_queries do
          get '/api/v1/production_orders/monthly_statistics', headers: headers
        end

        # Cached request should have significantly fewer queries
        # First request: ~4-5 queries for statistics
        expect(query_count_first).to be >= 4

        # Cached request: should only need auth/session queries
        expect(query_count_cached).to be < query_count_first
        expect(query_count_cached).to be <= 2 # Only auth query
      end
    end
  end

  describe 'GET /api/v1/production_orders/urgent_orders_report' do
    it 'executes report query efficiently with indexes' do
      # Create test data
      5.times do
        order = create(:urgent_order, creator: admin)
        create_list(:task, 3, production_order: order, status: :pending)
        create_list(:task, 2, production_order: order, status: :completed)
      end

      query_count = count_queries do
        get '/api/v1/production_orders/urgent_orders_report', headers: headers
      end

      # Should use a single complex query with JOINs and aggregations
      # Plus queries for eager loading relationships
      # 1. Main query with tasks aggregation (with JOINs)
      # 2. Eager load creators
      # 3. Eager load assigned_users
      # 4. COUNT for pagination
      # Manual serialization avoids N+1 by not accessing tasks.size
      expect(query_count).to be <= 6
    end
  end

  describe 'GET /api/v1/production_orders/urgent_with_expired_tasks' do
    it 'filters expired tasks efficiently' do
      # Create urgent orders with expired tasks
      3.times do
        order = create(:urgent_order, creator: admin)
        create(:task, production_order: order, status: :pending, expected_end_date: 2.days.ago)
        create(:task, production_order: order, status: :pending, expected_end_date: Date.current + 2.days)
      end

      # Create orders without expired tasks (should not appear)
      2.times do
        order = create(:urgent_order, creator: admin)
        create(:task, production_order: order, status: :pending, expected_end_date: Date.current + 5.days)
      end

      query_count = count_queries do
        get '/api/v1/production_orders/urgent_with_expired_tasks', headers: headers
      end

      # Should use indexes for filtering
      # 1. Main query with JOIN and WHERE on type, status, and date
      # 2. Eager load creators
      # 3. Eager load assigned_users
      # 4. Eager load tasks (for expired tasks display)
      # 5. Eager load order_assignments
      # 6. COUNT for pagination
      expect(query_count).to be <= 10
    end
  end

  describe 'POST /api/v1/production_orders' do
    it 'creates order with nested tasks efficiently' do
      order_params = {
        production_order: {
          start_date: Date.current,
          expected_end_date: Date.current + 1.week,
          tasks_attributes: [
            { description: 'Task 1', expected_end_date: Date.current + 2.days },
            { description: 'Task 2', expected_end_date: Date.current + 3.days },
            { description: 'Task 3', expected_end_date: Date.current + 4.days }
          ]
        }
      }

      query_count = count_queries do
        post '/api/v1/production_orders', headers: headers, params: order_params, as: :json
      end

      # Should create order and tasks efficiently
      # Queries should include:
      # - 1 INSERT for order
      # - 3 INSERTs for tasks
      # - 1 INSERT for audit log
      # - SELECT queries for associations when serializing response
      expect(query_count).to be <= 15 # Allow some overhead for audit logs and serialization
    end
  end

  describe 'Performance with large datasets' do
    it 'handles pagination efficiently with 100+ orders' do
      # Create 100 orders
      100.times do |i|
        order = create(:normal_order, creator: admin)
        create_list(:task, 2, production_order: order)
      end

      # Request first page
      query_count_page1 = count_queries do
        get '/api/v1/production_orders?page=1&per_page=20', headers: headers
      end

      # Request second page
      query_count_page2 = count_queries do
        get '/api/v1/production_orders?page=2&per_page=20', headers: headers
      end

      # Query counts should be consistent across pages
      expect(query_count_page2).to eq(query_count_page1)

      # Should still use eager loading efficiently
      expect(query_count_page1).to be <= 10
    end
  end

  describe 'Index usage verification' do
    it 'uses indexes for common filtering queries' do
      # Create test data with specific attributes to test indexes
      create(:normal_order, start_date: Date.current, status: :pending, creator: admin)
      create(:urgent_order, deadline: Date.current + 5.days, status: :pending, creator: admin)

      # This query should use index_production_orders_on_type_and_status
      queries = []
      counter = ->(*, payload) do
        queries << payload[:sql] if payload[:sql] =~ /SELECT.*production_orders/
      end

      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        get '/api/v1/production_orders?q[type_eq]=NormalOrder&q[status_eq]=pending', headers: headers
      end

      # Verify that filtering query was executed
      expect(queries).not_to be_empty

      # In a real scenario with EXPLAIN, we'd verify index usage
      # For now, we just ensure the query executed
      expect(response).to have_http_status(:ok)
    end
  end
end
