# frozen_string_literal: true

module Auditable
  extend ActiveSupport::Concern

  included do
    after_create :log_creation
    after_update :log_update
    before_destroy :log_deletion
  end

  def log_audit(action:, user:, change_details: nil, ip_address: nil, user_agent: nil)
    audit_logs.create!(
      user: user,
      action: action,
      change_details: change_details,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end

  private

  def log_creation
    return unless auditing_context_set?

    log_audit(
      action: 'created',
      user: Current.user,
      change_details: auditable_attributes,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    )
  end

  def log_update
    return unless auditing_context_set?
    return unless saved_changes.any?

    # Detect specific types of changes
    action = determine_update_action

    log_audit(
      action: action,
      user: Current.user,
      change_details: format_changes(saved_changes),
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    )
  end

  def log_deletion
    return unless auditing_context_set?

    log_audit(
      action: 'deleted',
      user: Current.user,
      change_details: auditable_attributes,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    )
  end

  def auditing_context_set?
    Current.user.present?
  end

  def determine_update_action
    if saved_changes.key?('status')
      'status_changed'
    elsif saved_changes.key?('type')
      'type_changed'
    else
      'updated'
    end
  end

  def auditable_attributes
    attributes.except('id', 'created_at', 'updated_at')
  end

  def format_changes(changes)
    changes.transform_values do |change|
      {
        from: change[0],
        to: change[1]
      }
    end
  end
end
