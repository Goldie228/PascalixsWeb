module Api
  module V1
    module Wiki
      class PagesController < BaseController
        before_action :set_wiki_page, only: [:show, :update, :destroy, :upload_image]
        
        # GET /api/v1/wiki/pages
        def index
          @pages = WikiPage.includes(:wiki_category, :wiki_downloads)
                           .published
                           .ordered
                           .page(params[:page])
                           .per(params[:per_page] || 20)
          
          render json: {
            pages: @pages.as_json(
              include: {
                wiki_category: { only: [:id, :name, :slug] },
                wiki_downloads: { 
                  only: [:id, :title, :description, :version, :slug, :position],
                  methods: [:file_url, :filename, :file_size]
                }
              },
              methods: [:images_with_variants, :category_breadcrumb]
            ),
            meta: pagination_meta(@pages)
          }
        end
        
        # GET /api/v1/wiki/pages/admin_index
        def admin_index
          pages = WikiPage.includes(:wiki_category, :wiki_downloads, images_attachments: :blob)
          
          if params[:search].present?
            query = "%#{params[:search]}%"
            pages = pages.where("wiki_pages.title ILIKE ? OR wiki_pages.slug ILIKE ?", query, query)
          end

          if params[:published].present?
            is_published = params[:published] == 'true'
            pages = pages.where(published: is_published)
          end

          sort_column = case params[:sort]
                        when 'title' then 'wiki_pages.title'
                        when 'position' then 'wiki_pages.position'
                        else 'wiki_pages.created_at'
                        end
          
          sort_direction = params[:order] == 'asc' ? 'asc' : 'desc'
          pages = pages.order("#{sort_column} #{sort_direction}")

          total_count = pages.count
          page_num = (params[:page] || 1).to_i
          per_page = (params[:per_page] || 25).to_i
          pages = pages.offset((page_num - 1) * per_page).limit(per_page)

          render json: { 
            pages: pages.as_json(
              include: {
                wiki_category: { only: [:id, :name, :slug] },
                wiki_downloads: { 
                  only: [:id, :title, :description, :version, :slug, :position],
                  methods: [:file_url, :filename, :file_size]
                }
              },
              methods: [:images_with_variants, :category_breadcrumb]
            ), 
            total_count: total_count 
          }
        end
        
        # GET /api/v1/wiki/pages/:slug
        def show
          render json: @wiki_page.page_details_with_associations
        end
        
        # POST /api/v1/wiki/pages
        def create
          @wiki_page = WikiPage.new(wiki_page_params)
          
          attach_images_from_params if params[:image_blob_ids].present?
          
          attach_temp_images_from_params if params[:temp_image_ids].present?

          if @wiki_page.save
            render json: @wiki_page.page_details_with_associations, status: :created
          else
            @wiki_page.images.purge
            render json: { errors: @wiki_page.errors }, status: :unprocessable_entity
          end
        end
        
        # PUT /api/v1/wiki/pages/:slug
        def update
          attach_images_from_params if params[:image_blob_ids].present?
          
          attach_temp_images_from_params if params[:temp_image_ids].present?
          
          if params[:remove_image_ids].present?
            @wiki_page.images.where(id: params[:remove_image_ids]).each(&:purge)
          end
          
          if @wiki_page.update(wiki_page_params)
            render json: @wiki_page.page_details_with_associations
          else
            render json: { errors: @wiki_page.errors }, status: :unprocessable_entity
          end
        end
        
        # DELETE /api/v1/wiki/pages/:slug
        def destroy
          @wiki_page.destroy
          head :no_content
        end
        
        # POST /api/v1/wiki/pages/:slug/upload_image
        def upload_image
          return render_error('No file provided', :bad_request) unless params[:file]
          
          image = params[:file]
          
          unless image.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
            return render_error('Invalid file type. Only JPEG, PNG, GIF, WEBP are allowed.', :unprocessable_entity)
          end

          if image.size > 5.megabytes
            return render_error('File too large. Maximum size is 5MB.', :unprocessable_entity)
          end
          
          @wiki_page.images.attach(image)
          
          image_attachment = @wiki_page.images.last
          
          ImageProcessorJob.perform_later(image_attachment.blob.key)
          
          render json: {
            id: image_attachment.id,
            signed_id: image_attachment.signed_id,
            url: rails_blob_url(image_attachment),
            filename: image_attachment.filename.to_s
          }
        end
        
        # POST /api/v1/wiki/pages/upload_temporary_image
        def upload_temporary_image
          return render_error('User not found', :unauthorized) unless current_user
          return render_error('No file provided', :bad_request) unless params[:file]
          
          file = params[:file]
          
          allowed_images = %w[image/jpeg image/png image/gif image/webp]
          allowed_files = ['application/zip', 'application/x-rar-compressed', 'application/x-7z-compressed', 'application/java-archive']
          
          file_type = if file.content_type.in?(allowed_images)
                        'image'
                      elsif file.content_type.in?(allowed_files)
                        'file'
                      else
                        return render_error('Invalid file format', :unprocessable_entity)
                      end
          
          if file_type == 'image' && file.size > 5.megabytes
            return render_error('Image too large. Maximum size is 5MB.', :unprocessable_entity)
          end
          
          if file_type == 'file' && file.size > 100.megabytes
            return render_error('File too large. Maximum size is 100MB.', :unprocessable_entity)
          end
          
          current_user.temp_files.attach(file)
          attached = current_user.temp_files.last
          
          render json: {
            url: rails_blob_url(attached),
            signed_id: attached.signed_id,
            type: file_type,
            filename: attached.filename.to_s
          }, status: :created
        end

        def positions
          category_id = params[:category_id].presence
          
          pages = if category_id
            WikiPage.where(wiki_category_id: category_id)
          else
            WikiPage.all
          end
          
          positions_data = pages
            .select(:id, :position, :title)
            .order(:position)
            .map { |p| { position: p.position, title: p.title, page_id: p.id } }
          
          render json: { positions: positions_data }
        end
        
        # GET /api/v1/wiki/pages/check_slug
        def check_slug
          slug = params[:slug]&.parameterize
          exists = WikiPage.exists?(slug: slug)
          
          render json: { 
            available: !exists,
            slug: slug
          }
        end
        
        # DELETE /api/v1/wiki/pages/:slug/images/:image_id
        def destroy_image
          image = @wiki_page.images.find(params[:image_id])
          image.purge
          head :no_content
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Image not found on this page' }, status: :not_found
        end
        
        private
        
        def current_user
          return @current_user if @current_user
          user_id = request.headers["X-User-ID"]
          @current_user = User.find_by(id: user_id) if user_id.present?
        end
        
        def wiki_page_params
          params.require(:wiki_page).permit(
            :title, 
            :slug, 
            :content, 
            :wiki_category_id, 
            :published, 
            :position
          )
        end
        
        def attach_images_from_params
          return unless params[:images].present?
          
          Array(params[:images]).each do |image|
            attach_image(@wiki_page, image)
          end
        end
        
        def attach_temp_images_from_params
          return unless params[:temp_image_ids].present? && current_user
          
          params[:temp_image_ids].each do |signed_id|
            begin
              blob_id = ActiveStorage::Blob.signed_id_verifier.verify(signed_id, purpose: :blob_id)
            rescue ActiveSupport::MessageVerifier::InvalidSignature
              next
            end

            attachment = ActiveStorage::Attachment.find_by(
              record_type: 'User',
              record_id: current_user.id,
              name: 'temp_files',
              blob_id: blob_id
            )

            if attachment
              @wiki_page.images.attach(attachment.blob) if attachment.blob.content_type.start_with?('image/')
              attachment.purge
            end
          end
        end
      end
    end
  end
end