
module Api
  module V1
    module Wiki
      class PagesController < BaseController
        
        # PUBLIC: Список всех страниц (опционально, для поиска или карты сайта)
        def index
          # Показываем только опубликованные
          @pages = WikiPage.published.includes(:wiki_category, wiki_downloads: :file_attachment)
          render json: @pages
        end

        # PUBLIC: Просмотр страницы (самое частое действие)
        def show
          # Ищем только среди опубликованных
          @page = WikiPage.includes(:wiki_downloads, :wiki_category, images_attachments: :blob)
                          .published.find_by!(slug: params[:slug])
          
          # В реальном проекте лучше использовать Serializer для форматирования JSON
          render json: @page.as_json(
            include: {
              wiki_category: { only: [:id, :name, :slug] },
              wiki_downloads: { 
                only: [:id, :title, :description], 
                methods: [:file_url] # Если добавишь метод в модель WikiDownload
              },
              images: { 
                only: [:id],
                methods: [:url] # ActiveStorage метод
              }
            }
          )
        end

        # ADMIN: Создание страницы
        def create
          @page = WikiPage.new(page_params)
          
          # Обработка загрузки картинок при создании
          if params[:images].present?
            params[:images].each do |img|
              attach_image(@page, img) # Метод из BaseController
            end
          end

          if @page.save
            render json: @page, status: :created
          else
            render_error(@page.errors.full_messages.join(', '))
          end
        end

        # ADMIN: Обновление страницы
        def update
          @page = WikiPage.find(params[:id])
          
          # 1. Обработка добавления картинок
          # Array(...) гарантирует, что мы переберем массив даже если params[:images] nil
          Array(params[:images]).each do |img|
            attach_image(@page, img)
          end

          # 2. Обработка удаления картинок
          if params[:remove_image_ids].present?
            @page.images.where(id: params[:remove_image_ids]).each(&:purge)
          end

          # 3. Обновление полей страницы (без картинок, чтобы их не перезаписать пустым значением)
          if @page.update(page_params_without_images)
            render json: @page
          else
            render_error(@page.errors.full_messages.join(', '))
          end
        end

        # ADMIN: Удаление страницы
        def destroy
          @page = WikiPage.find(params[:id])
          @page.destroy
          head :no_content
        end

        # ADMIN: Отдельный экшен для загрузки картинки (для WYSIWYG редактора)
        def upload_image
          @page = WikiPage.find(params[:id])
          
          if params[:file].blank?
            return render_error('Файл не загружен')
          end

          if attach_image(@page, params[:file])
            # Возвращаем URL для вставки в редактор
            render json: { url: rails_blob_url(@page.images.last), id: @page.images.last.id }
          else
            render_error('Ошибка загрузки изображения')
          end
        end

        private

        def page_params
          params.permit(:title, :slug, :content, :wiki_category_id, :position, :published)
        end
        
        def page_params_without_images
          params.permit(:title, :slug, :content, :wiki_category_id, :position, :published)
        end
      end
    end
  end
end
