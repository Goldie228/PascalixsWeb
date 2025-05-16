class PagesController < ApplicationController
  def home
  end

  def update_timezone
    time_zone = params[:time_zone]
    if time_zone.present?
      session[:time_zone] = time_zone
      redirect_back(fallback_location: root_path)
    else
      render json: { error: "Time zone not provided" }, status: :bad_request
    end
  end
end
