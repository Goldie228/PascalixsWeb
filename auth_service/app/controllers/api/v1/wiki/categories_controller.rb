
module Api
  module V1
    module Wiki
      class CategoriesController < BaseController
        before_action :set_wiki_category, only: [:show, :update, :destroy, :pages]
        
        # GET /api/v1/wiki/categories
        def index
          @categories = WikiCategory.includes(:children, :wiki_pages)
                                    .roots
                                    .alphabetically
          
          render json: @categories.as_json(
            include: {
              children: {
                only: [:id, :name, :slug, :position],
                include: :wiki_pages
              },
              wiki_pages: { only: [:id, :title, :slug, :published] }
            }
          )
        end
        
        # GET /api/v1/wiki/categories/tree
        def tree
          cache_key = "wiki_categories_tree_v1"
          
          @categories_tree = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
            WikiCategory.roots.includes(:children, :wiki_pages).to_a
          end
          
          render json: build_tree_json(@categories_tree)
        end
        
        # POST /api/v1/wiki/categories
        def create
          @category = WikiCategory.new(category_params)
          
          if @category.save
            Rails.cache.delete("wiki_categories_tree_v1")
            render json: @category, status: :created
          else
            render json: { errors: @category.errors }, status: :unprocessable_entity
          end
        end
        
        # GET /api/v1/wiki/categories/:slug
        def show
          render json: @wiki_category.as_json(
            include: {
              parent: { only: [:id, :name, :slug] },
              children: { only: [:id, :name, :slug, :position] },
              wiki_pages: { 
                only: [:id, :title, :slug, :published, :position],
                methods: [:images_with_variants] 
              }
            },
            methods: [:breadcrumb_path]
          )
        end
        
        # PUT /api/v1/wiki/categories/:slug
        def update
          new_parent = WikiCategory.find_by(id: category_params[:parent_id]) if category_params[:parent_id].present?
          if new_parent && @wiki_category.descendant_of?(new_parent)
            return render json: { error: "Cannot move a category to be its own descendant" }, status: :unprocessable_entity
          end

          if @wiki_category.update(category_params)
            Rails.cache.delete("wiki_categories_tree_v1")
            render json: @wiki_category
          else
            render json: { errors: @wiki_category.errors }, status: :unprocessable_entity
          end
        end
        
        # DELETE /api/v1/wiki/categories/:slug
        def destroy
          if @wiki_category.children.exists?
            render json: { error: 'Cannot delete category with subcategories' }, status: :conflict
          elsif @wiki_category.wiki_pages.exists?
            render json: { error: 'Cannot delete category with existing pages' }, status: :conflict
          else
            @wiki_category.destroy
            Rails.cache.delete("wiki_categories_tree_v1")
            head :no_content
          end
        end
        
        # GET /api/v1/wiki/categories/:slug/pages
        def pages
          include_children = params[:include_children] == 'true'
          category_ids = include_children ? @wiki_category.self_and_descendants.pluck(:id) : [@wiki_category.id]
          
          @pages = WikiPage.where(wiki_category_id: category_ids)
                           .published
                           .ordered
                           .page(params[:page])
                           .per(params[:per_page] || 20)
          
          render json: {
            pages: @pages.as_json(methods: [:images_with_variants]),
            category: @wiki_category.as_json(only: [:id, :name, :slug], methods: [:breadcrumb_path]),
            meta: pagination_meta(@pages)
          }
        end
        
        # POST /api/v1/wiki/categories/reorder
        def reorder
          categories_data = params.require(:categories)
          
          WikiCategory.transaction do
            categories_data.each do |cat_data|
              category = WikiCategory.find(cat_data[:id])
              category.update_column(:position, cat_data[:position])
            end
          end
          
          Rails.cache.delete("wiki_categories_tree_v1")
          head :no_content
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Category not found: #{e.message}" }, status: :not_found
        rescue => e
          render json: { error: "Failed to reorder categories: #{e.message}" }, status: :unprocessable_entity
        end
        
        private
        
        def category_params
          params.require(:wiki_category).permit(:name, :slug, :description, :parent_id, :position)
        end
        
        def build_tree_json(categories)
          categories.map do |category|
            {
              id: category.id,
              name: category.name,
              slug: category.slug,
              description: category.description,
              position: category.position,
              pages_count: category.wiki_pages.published.count,
              children: build_tree_json(category.children)
            }
          end
        end
      end
    end
  end
end
