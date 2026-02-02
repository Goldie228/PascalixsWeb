
module Api
  module V1
    module Wiki
      class PagesController < BaseController

        def index
          @pages = WikiPage.published.includes(:wiki_category, wiki_downloads: :file_attachment)
          render json: @pages
        end

        # GET /api/v1/wiki/pages/admin_index
        def admin_index
          # Проверка админа подхватится автоматически в BaseController
          
          # Базовый запрос сpreload'ом данных
          pages = WikiPage.includes(:wiki_category, wiki_downloads: :file_attachment)
          
          # --- Фильтрация (Search & Filters) ---
          
          # Поиск по названию или slug
          if params[:search].present?
            query = "%#{params[:search]}%"
            pages = pages.where("wiki_pages.title ILIKE ? OR wiki_pages.slug ILIKE ?", query, query)
          end

          # Фильтр по статусу публикации
          if params[:published].present?
            is_published = params[:published] == 'true'
            pages = pages.where(published: is_published)
          end

          # --- Сортировка ---
          
          sort_column = case params[:sort]
                        when 'title' then 'wiki_pages.title'
                        when 'position' then 'wiki_pages.position'
                        else 'wiki_pages.created_at'
                        end
          
          sort_direction = params[:order] == 'asc' ? 'asc' : 'desc'
          pages = pages.order("#{sort_column} #{sort_direction}")

          # --- Пагинация ---
          
          # Считаем общее количество ДО пагинации
          total_count = pages.count
          
          # Применяем пагинацию вручную, чтобы не зависеть от конкретных гемов
          page_num = (params[:page] || 1).to_i
          per_page = (params[:per_page] || 25).to_i
          pages = pages.offset((page_num - 1) * per_page).limit(per_page)

          # Возвращаем JSON в формате, ожидаемом фронтендом
          render json: { 
            pages: pages, 
            total_count: total_count 
          }
        end

        def show
          @page = WikiPage.includes(:wiki_downloads, :wiki_category, images_attachments: :blob)
                          .published.find_by!(slug: params[:slug])

          render json: @page.as_json(
            include: {
              wiki_category: { only: [:id, :name, :slug] },
              wiki_downloads: { only: [:id, :title, :description], methods: [:file_url] },
              images: { only: [:id], methods: [:url] }
            }
          )
        end

        def create
          @page = WikiPage.new(page_params)

          if params[:temp_image_ids].present?
            params[:temp_image_ids].each do |signed_id|
              attach_signed_image(@page, signed_id)
            end
          end

          if params[:images].present?
            params[:images].each do |img|
              attach_image(@page, img)
            end
          end

          if @page.save
            render json: @page, status: :created
          else
            render_error(@page.errors.full_messages.join(', '))
          end
        end

        def update
          @page = WikiPage.find(params[:id])

          Array(params[:images]).each { |img| attach_image(@page, img) }

          if params[:remove_image_ids].present?
            @page.images.where(id: params[:remove_image_ids]).each(&:purge)
          end

          if @page.update(page_params_without_images)
            render json: @page
          else
            render_error(@page.errors.full_messages.join(', '))
          end
        end

        def destroy
          @page = WikiPage.find(params[:id])
          @page.destroy
          head :no_content
        end

        def upload_image
          @page = WikiPage.find(params[:id])
          return render_error('Файл не загружен') if params[:file].blank?

          if attach_image(@page, params[:file])
            render json: { url: rails_blob_url(@page.images.last), id: @page.images.last.signed_id }
          else
            render_error('Ошибка загрузки изображения')
          end
        end

        def current_user
          # Если @current_user уже найден (например, через сессию), возвращаем его
          return @current_user if @current_user

          # Иначе ищем по заголовку X-User-ID, так как мы уже проверили API KEY
          user_id = request.headers["X-User-ID"]
          @current_user = User.find_by(id: user_id) if user_id.present?
        end

        def upload_temporary_image
          # Теперь current_user вернет юзера по X-User-ID
          return render_error('User not found', :unauthorized) unless current_user
          return render_error('Файл не загружен') if params[:file].blank?

          allowed_images = %w[image/jpeg image/png image/gif image/webp]
          allowed_files = ['application/zip', 'application/x-rar-compressed', 'application/x-7z-compressed', 'application/java-archive']

          file_type = if params[:file].content_type.in?(allowed_images)
                        'image'
                      elsif params[:file].content_type.in?(allowed_files)
                        'file'
                      else
                        return render_error('Неверный формат файла', :unprocessable_entity)
                      end

          current_user.temp_images.attach(params[:file])
          attached = current_user.temp_images.last

          render json: {
            url: rails_blob_url(attached),
            signed_id: attached.signed_id,
            type: file_type,
            filename: attached.filename.to_s
          }, status: :created
        end

        private

        def page_params
          params.require(:wiki_page).permit(:title, :slug, :content, :wiki_category_id, :position, :published)
        end

        def page_params_without_images
          params.require(:wiki_page).permit(:title, :slug, :content, :wiki_category_id, :position, :published)
        end

        def attach_signed_image(record, signed_id)
          begin
            blob_id = ActiveStorage::Blob.signed_id_verifier.verify(signed_id, purpose: :blob_id)
          rescue ActiveSupport::MessageVerifier::InvalidSignature
            return nil
          end

          attachment = ActiveStorage::Attachment.find_by(
            record_type: 'User',
            record_id: current_user.id,
            name: 'temp_images',
            blob_id: blob_id
          )

          if attachment
            record.images.attach(attachment.blob)
            attachment.purge
          end
        end
      end
    end
  end
end
