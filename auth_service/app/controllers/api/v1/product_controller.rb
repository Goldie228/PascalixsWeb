module Api
  module V1
    class ProductController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_service_request

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
          type:  product_type,
          price: price
        }, status: :ok
      end
    end
  end
end
