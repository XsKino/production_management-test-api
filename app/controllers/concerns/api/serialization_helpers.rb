# frozen_string_literal: true

module Api
  module SerializationHelpers
    extend ActiveSupport::Concern

    # Generic method to serialize resources using Fast JSON API serializers
    # Supports both single resources and collections
    #
    # @param resource [ActiveRecord::Base, ActiveRecord::Relation, Array] - Resource(s) to serialize
    # @param options [Hash] - Options for serialization
    # @option options [Symbol, Array] :include - Relationships to include (e.g., [:creator, :assigned_users])
    # @option options [Class] :serializer - Custom serializer class to use
    # @option options [Hash] :merge - Additional attributes to merge into each serialized record
    # @option options [Proc] :transform - Custom transformation block for each serialized record
    #
    # @return [Hash, Array<Hash>] - Serialized data
    #
    # Examples:
    #   serialize(user)
    #   serialize(users)
    #   serialize(order, include: [:creator, :assigned_users])
    #   serialize(order, include: [:tasks], merge: { tasks_summary: {...} })
    #   serialize(task, merge: { is_overdue: task.overdue? })
    def serialize(resource, options = {})
      return nil if resource.nil?

      # Determine if resource is a collection
      is_collection = resource.is_a?(ActiveRecord::Relation) || resource.is_a?(Array)

      # Determine serializer class
      serializer_class = options[:serializer] || determine_serializer_class(resource, is_collection)

      # Build serializer options
      serializer_opts = {}
      serializer_opts[:include] = options[:include] if options[:include]

      # Serialize using Fast JSON API
      serialized = serializer_class.new(
        resource,
        serializer_opts
      ).serializable_hash

      # Extract data and format
      if is_collection
        data = serialized[:data].map { |item| extract_attributes(item, serialized[:included]) }
      else
        data = extract_attributes(serialized[:data], serialized[:included])
      end

      # Apply merge if provided
      if options[:merge]
        data = is_collection ? data.map { |item| item.merge(options[:merge]) } : data.merge(options[:merge])
      end

      # Apply custom transformation if provided
      if options[:transform]
        data = is_collection ? data.map(&options[:transform]) : options[:transform].call(data)
      end

      data
    end

    private

    # Determine the appropriate serializer class based on resource type
    def determine_serializer_class(resource, is_collection)
      # Get the actual class (handle collections)
      klass = if is_collection
                resource.first&.class || resource.klass
              else
                resource.class
              end

      # Handle STI - UrgentOrder should use UrgentOrderSerializer
      serializer_name = "#{klass.name}Serializer"

      begin
        serializer_name.constantize
      rescue NameError
        raise ArgumentError, "No serializer found for #{klass.name}. Expected #{serializer_name} to exist."
      end
    end

    # Extract attributes from Fast JSON API format and merge included relationships
    def extract_attributes(data, included = nil)
      return nil if data.nil?

      attributes = data[:attributes].dup
      relationships = data[:relationships] || {}

      # Merge included relationships into attributes
      if included.present?
        relationships.each do |rel_name, rel_data|
          next unless rel_data[:data]

          if rel_data[:data].is_a?(Array)
            # Has-many relationship
            attributes[rel_name] = rel_data[:data].map do |item_ref|
              found = find_included_data(included, item_ref[:type], item_ref[:id])
              # Add is_overdue flag for tasks
              if item_ref[:type] == :task && found
                found = found.merge(
                  is_overdue: found[:expected_end_date] < Date.current && found[:status] == 'pending'
                )
              end
              found
            end.compact
          else
            # Belongs-to relationship
            attributes[rel_name] = find_included_data(
              included,
              rel_data[:data][:type],
              rel_data[:data][:id]
            )
          end
        end
      end

      attributes
    end

    # Find an included resource by type and id
    # FastJsonApi uses singular types in relationships (e.g., :assigned_user)
    # but plural/base types in included (e.g., :user)
    def find_included_data(included, type, id)
      # Try exact type match first
      item = included.find { |i| i[:type] == type && i[:id] == id.to_s }

      # If not found and type is singular (e.g., :assigned_user, :creator),
      # try base type (e.g., :user)
      if !item && type.to_s.include?('_')
        base_type = type.to_s.split('_').last.to_sym
        item = included.find { |i| i[:type] == base_type && i[:id] == id.to_s }
      end

      item[:attributes] if item
    end
  end
end
