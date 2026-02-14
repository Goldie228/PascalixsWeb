
module Api
  module V1
    module Wiki
      class DownloadsController < BaseController
        before_action :set_wiki_page, only: [:index, :create, :destroy]
        
        # GET /api/v1/wiki/pages/:slug/files
        def index
          @files = @wiki_page.files.attached? ? @wiki_page.files : []
          
          render json: @files.map do |file|
            {
              id: file.id,
              signed_id: file.signed_id,
              filename: file.filename.to_s,
              content_type: file.content_type,
              byte_size: file.byte_size,
              url: rails_blob_url(file),
              created_at: file.created_at
            }
          end
        end
        
        # POST /api/v1/wiki/pages/:slug/files
        def create
          return render_error('No file provided', :bad_request) unless params[:file]
          
          file = params[:file]
          
          allowed_files = [
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/vnd.ms-powerpoint',
            'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'text/plain',
            'text/csv',
            'application/json',
            'application/xml'
          ]
          
          unless file.content_type.in?(allowed_files)
            return render_error('Invalid file type. Only documents, spreadsheets, presentations, PDF, TXT, CSV, JSON, XML are allowed.', :unprocessable_entity)
          end

          if file.size > 50.megabytes
            return render_error('File too large. Maximum size is 50MB.', :unprocessable_entity)
          end
          
          @wiki_page.files.attach(file)
          
          attached_file = @wiki_page.files.last
          
          render json: {
            id: attached_file.id,
            signed_id: attached_file.signed_id,
            filename: attached_file.filename.to_s,
            content_type: attached_file.content_type,
            byte_size: attached_file.byte_size,
            url: rails_blob_url(attached_file),
            created_at: attached_file.created_at
          }, status: :created
        end
        
        # DELETE /api/v1/wiki/pages/:slug/files/:file_id
        def destroy
          file = @wiki_page.files.find(params[:file_id])
          file.purge
          head :no_content
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'File not found on this page' }, status: :not_found
        end
        
        # POST /api/v1/wiki/page_files/upload_temporary
        def upload_temporary
          return render_error('User not found', :unauthorized) unless current_user
          return render_error('No file provided', :bad_request) unless params[:file]
          
          file = params[:file]
          
          allowed_files = [
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/vnd.ms-powerpoint',
            'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'text/plain',
            'text/csv',
            'application/json',
            'application/xml'
          ]
          
          unless file.content_type.in?(allowed_files)
            return render_error('Invalid file type. Only documents, spreadsheets, presentations, PDF, TXT, CSV, JSON, XML are allowed.', :unprocessable_entity)
          end

          if file.size > 50.megabytes
            return render_error('File too large. Maximum size is 50MB.', :unprocessable_entity)
          end
          
          current_user.temp_files.attach(file)
          attached = current_user.temp_files.last
          
          render json: {
            url: rails_blob_url(attached),
            signed_id: attached.signed_id,
            filename: attached.filename.to_s,
            content_type: attached.content_type
          }, status: :created
        end
        
        private
        
        def current_user
          return @current_user if @current_user
          user_id = request.headers["X-User-ID"]
          @current_user = User.find_by(id: user_id) if user_id.present?
        end
      end
    end
  end
end
