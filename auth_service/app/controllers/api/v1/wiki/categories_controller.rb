
module Api
  module V1
    module Wiki
      class CategoriesController < BaseController

        # PUBLIC: Получить дерево категорий
        def index
          # Жадная загрузка корневых категорий и их детей
          @categories = WikiCategory.roots.includes(:children)
          render json: @categories
        end

        # PUBLIC: Получить страницы конкретной категории по slug
        def pages
          @category = WikiCategory.find_by!(slug: params[:slug])
          # Только опубликованные и отсортированные страницы
          @pages = @category.wiki_pages.published.ordered
          render json: @pages, include: [:wiki_downloads]
        end

        # ADMIN: Создать категорию
        def create
          @category = WikiCategory.new(category_params)
          if @category.save
            render json: @category, status: :created
          else
            render_error(@category.errors.full_messages.join(', '))
          end
        end

        # ADMIN: Обновить категорию (в т.ч. родителя)
        def update
          @category = WikiCategory.find(params[:id])
          if @category.update(category_params)
            render json: @category
          else
            render_error(@category.errors.full_messages.join(', '))
          end
        end

        # ADMIN: Удалить категорию
        def destroy
          @category = WikiCategory.find(params[:id])
          @category.destroy
          head :no_content
        end

        private

        def category_params
          params.permit(:name, :slug, :parent_id, :description)
        end
      end
    end
  end
end
