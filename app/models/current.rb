# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :ip_address, :user_agent
end
