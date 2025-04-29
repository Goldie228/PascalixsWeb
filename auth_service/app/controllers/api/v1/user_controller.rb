module Api
  module V1
    class UserController < ApplicationController
      before_action :set_user, only: [:fields]

      def fields
        validate_fields!
        render_user_data(@user)
      end

      def current_user_fields
        validate_fields!
        render_user_data(current_user)
      end

      def invalid_request
        render json: { error: 'Missing user ID. Use /api/v1/me/fields for current user' }, 
               status: :bad_request
      end

      private

      def validate_fields!
        allowed_fields = %w[discord minecraft updated_at created_at time_zone]
        invalid = params[:fields].to_s.split(',') - allowed_fields
        
        return if invalid.empty?
        
        render json: { 
          error: "Invalid fields requested: #{invalid.join(', ')}",
          allowed_fields: allowed_fields 
        }, status: :unprocessable_entity
      end
      
      def invalid_request
        render json: { 
          error: "Invalid URL format. Use either:", 
          valid_formats: [
            "/api/v1/users/{id}/fields?fields=field1,field2",
            "/api/v1/me/fields?fields=field1,field2"
          ]
        }, status: :bad_request
      end

      def set_user
        @user = User.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      def render_user_data(user)
        fields = params[:fields].to_s.split(',').map(&:strip)
        
        data = user.as_json(
          only: valid_attributes(fields),
          include: valid_associations(fields)
        )

        render json: data
      end

      def valid_attributes(fields)
        fields & User.attribute_names
      end

      def valid_associations(fields)
        associations = {}
        associations[:discord_account] = { only: [:username, :avatar] } if fields.include?('discord')
        associations[:minecraft_account] = { only: [:nickname] } if fields.include?('minecraft')
        associations.presence
      end
    end
  end
end