# frozen_string_literal: true

# Service object for managing monthly statistics cache keys and invalidation
# Centralizes cache logic that was previously scattered in ProductionOrdersController
class MonthlyStatisticsCacheService
  # Cache key format: monthly_stats/{role}/{user_id_if_operator}/{year}/{month}
  CACHE_KEY_PREFIX = 'monthly_stats'

  # Roles that see all orders (their cache doesn't depend on specific users)
  GLOBAL_ROLES = %w[admin production_manager].freeze

  class << self
    # Generate cache key for monthly statistics
    #
    # @param user [User] the user requesting statistics
    # @param month_start [Date] the start of the month (defaults to current month)
    # @return [String] the cache key
    #
    # Examples:
    #   # Admin viewing stats for December 2025
    #   build_key(admin_user, Date.new(2025, 12, 1))
    #   # => "monthly_stats/admin/2025/12"
    #
    #   # Operator viewing their stats for December 2025
    #   build_key(operator_user, Date.new(2025, 12, 1))
    #   # => "monthly_stats/operator/123/2025/12"
    def build_key(user, month_start = Date.current.beginning_of_month)
      key_parts = [CACHE_KEY_PREFIX, user.role, month_start.year, month_start.month]

      # Operators only see their own orders, so include user_id in cache key
      key_parts.insert(2, user.id) if user.operator?

      key_parts.join('/')
    end

    # Invalidate monthly statistics cache for the current month
    # Intelligently invalidates only the caches that might be affected by the order
    #
    # @param production_order [ProductionOrder, nil] the order that triggered the invalidation
    # @param month_start [Date] the month to invalidate (defaults to current month)
    # @return [Array<String>] array of invalidated cache keys (for debugging/logging)
    def invalidate(production_order = nil, month_start = Date.current.beginning_of_month)
      invalidated_keys = []

      # Invalidate cache for all roles that see all orders (admin, production_manager)
      invalidated_keys += invalidate_global_roles(month_start)

      # Invalidate cache for specific operators affected by this order
      if production_order
        invalidated_keys += invalidate_affected_operators(production_order, month_start)
      end

      invalidated_keys
    end

    private

    # Invalidate cache for roles that see all orders (admin, production_manager)
    def invalidate_global_roles(month_start)
      GLOBAL_ROLES.map do |role|
        cache_key = [CACHE_KEY_PREFIX, role, month_start.year, month_start.month].join('/')
        Rails.cache.delete(cache_key)
        cache_key
      end
    end

    # Invalidate cache for operators affected by the production order
    # (creator if operator, and all assigned operators)
    def invalidate_affected_operators(production_order, month_start)
      invalidated_keys = []

      # Invalidate creator's cache if they're an operator
      if production_order.creator&.operator?
        cache_key = build_operator_key(production_order.creator.id, month_start)
        Rails.cache.delete(cache_key)
        invalidated_keys << cache_key
      end

      # Invalidate assigned operators' cache
      production_order.assigned_users.where(role: :operator).each do |user|
        cache_key = build_operator_key(user.id, month_start)
        Rails.cache.delete(cache_key)
        invalidated_keys << cache_key
      end

      invalidated_keys
    end

    # Build cache key for a specific operator
    def build_operator_key(operator_id, month_start)
      [CACHE_KEY_PREFIX, 'operator', operator_id, month_start.year, month_start.month].join('/')
    end
  end
end
