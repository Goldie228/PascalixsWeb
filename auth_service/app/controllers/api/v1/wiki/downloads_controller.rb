
module Api
  module V1
    module Wiki
      class DownloadsController < BaseController
        
        def index
          @page = WikiPage.published.find_by!(slug: params[:slug]) # ИСПРАВЛЕНО: params[:slug]
          render json: @page.wiki_downloads.ordered
        end

        def create
          @page = WikiPage.find_by!(slug: params[:slug]) # ИСПРАВЛЕНО: params[:slug]
          
          @download = @page.wiki_downloads.new(download_params)
          
          # Базовая проверка наличия файла перед сохранением (бывает полезна для быстрого ответа)
          return render_error('Файл обязателен') unless params[:file].present?
          
          # Server-Side валидация типа (Security!)
          allowed_types = ['application/zip', 'application/x-rar-compressed', 'application/x-7z-compressed', 'application/java-archive']
          unless params[:file].content_type.in?(allowed_types)
            return render_error('Неверный тип файла. Разрешены: zip, rar, 7z, jar.')
          end

          @download.file.attach(params[:file])

          if @download.save
            render json: @download, status: :created
          else
            render_error(@download.errors.full_messages.join(', '))
          end
        end

        def update
          @download = WikiDownload.find(params[:id])
          
          # Обновляем файл, если пришел новый
          @download.file.attach(params[:file]) if params[:file].present?

          if @download.update(download_params_without_file)
            render json: @download
          else
            render_error(@download.errors.full_messages.join(', '))
          end
        end

        def destroy
          @download = WikiDownload.find(params[:id])
          @download.destroy 
          head :no_content
        end

        private

        def download_params
          params.permit(:title, :description, :position, :file)
        end

        def download_params_without_file
          params.permit(:title, :description, :position)
        end
      end
    end
  end
end
