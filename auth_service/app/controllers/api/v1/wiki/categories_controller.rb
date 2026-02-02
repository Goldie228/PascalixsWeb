
module Api
  module V1
    module Wiki
      class CategoriesController < BaseController
        
        # PUBLIC: Получить дерево категорий (для меню)
        def index
          # Жадная загрузка детей и страниц, чтобы избежать N+1
          # Используем includes для детей 2-х уровней, так как меню обычно неглубокое
          @categories = WikiCategory.roots.includes(
            children: { children: :wiki_pages }, 
            wiki_pages: :wiki_downloads
          )
          
          render json: @categories, each_serializer: WikiCategoryTreeSerializer # Рекомендую использовать serializers, но если нет - см. render json ниже
          
          # Если не используешь ActiveModel::Serializers, можно так:
          # render json: WikiCategorySerializer.new(@categories).serializable_hash 
        end

        # PUBLIC: Получить страницы конкретной категории (с пагинацией, если страниц много)
        def pages
          @category = WikiCategory.find_by!(slug: params[:slug])
          # Берем только опубликованные страницы
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
          
          # Модель настроена на dependent: :nullify, страницы станут без категории
          @category.destroy
          head :no_content
        end

        private

        def category_params
          # Разрешаем менять родителя, модель сама проверит циклы
          params.permit(:name, :slug, :description, :parent_id)
        end
      end
    end
  end
end
