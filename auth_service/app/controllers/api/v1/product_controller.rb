module Api
  module V1
    class ProductController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_service_request

      before_action :is_admin?, except: [ :show ]

      def index
        products = Product.all.order(:product_type)

        render json: {
          products: products.as_json(only: [ :id, :product_type, :price, :created_at, :updated_at ])
        }, status: :ok
      end

      def show
        product_type = params[:product_type].to_s.strip.downcase
        product = Product.find_by(product_type: product_type)

        if product.nil?
          return render json: { error: "not found" }, status: :not_found
        end

        price = product.price
        if price.blank?
          return render json: { error: "price not set" }, status: :unprocessable_entity
        end

        render json: {
          type: product_type,
          price: price
        }, status: :ok
      end

      def update
        product_type = params[:product_type].to_s.strip.downcase
        product = Product.find_by(product_type: product_type)

        if product.nil?
          return render json: { error: "not found" }, status: :not_found
        end

        if product.update(product_params)
          render json: {
            status: "ok",
            product: product.as_json(only: [ :id, :product_type, :price ])
          }, status: :ok
        else
          render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def is_admin?
        user_id = request.headers["X-User-ID"]

        unless user_id.present?
          render json: { error: "missing X-User-ID header" }, status: :unauthorized
          return false
        end

        user = User.find_by(id: user_id)

        unless user && [ 3, 4 ].include?(user.role_id)
          render json: { error: "not admin" }, status: :forbidden
          return false
        end

        true
      end

      def product_params
        params.permit(:product_type, :price)
      end
    end
  end
end
