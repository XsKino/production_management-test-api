# frozen_string_literal: true

class UserSerializer
  include FastJsonapi::ObjectSerializer

  attributes :id, :email, :name, :role, :created_at, :updated_at

  # Don't include password_digest in serialization
  attribute :role do |user|
    user.role
  end
end
