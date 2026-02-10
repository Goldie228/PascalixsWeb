
module Api
  module V1
    module Wiki
      class BaseController < ApplicationController
        before_action :require_admin!, except: [:index, :show]
        skip_before_action :verify_authenticity_token
        
        rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
        rescue_from ActionController::ParameterMissing, with: :parameter_missing
        
        private

        def require_admin!
          unless is_admin?
            render json: { error: I18n.t('controllers.wiki.access_denied') }, status: :forbidden
          end
        end

        def render_error(message, status = :unprocessable_entity)
          render json: { error: message }, status: status
        end

        def render_not_found
          render json: { error: I18n.t('controllers.wiki.not_found') }, status: :not_found
        end

        def parameter_missing(exception)
          render json: { error: exception.message }, status: :unprocessable_entity
        end

        def set_wiki_page
          @wiki_page = WikiPage.find_by!(slug: params[:slug])
        end

        def set_wiki_category
          @wiki_category = WikiCategory.find_by!(slug: params[:slug])
        end
        
        def pagination_meta(collection)
          {
            current_page: collection.current_page,
            total_pages: collection.total_pages,
            total_count: collection.total_count,
            per_page: collection.limit_value
          }
        end
      end
    end
  end
end
