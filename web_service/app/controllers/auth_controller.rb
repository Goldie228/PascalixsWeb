class AuthController < ApplicationController
  def login
    if @current_user
      redirect_to localized_root_path
    end
  end

  def discord
  end

  def register_minecraft
    unless current_user
      redirect_to localized_root_path
      return
    end

    @minecraft_account = current_user.build_minecraft_account
  end

  def submit_registration
    return redirect_to(localized_root_path) if current_user.nil?

    correlation_id = SecureRandom.uuid

    produce_with_retries(
      "minecraft_registration_requests",
      payload: {
        user_id: current_user.id,
        locale: I18n.locale,
        **minecraft_params
      }.merge(correlation_id: correlation_id)
    )

    RegistrationResponseJob.perform_later(correlation_id, session[:user_id])

    respond_to do |format|
      format.json do
        render json: {
          status: "pending",
          message: "Registration in process",
          correlation_id: correlation_id
        }, status: :accepted
      end
      format.html do
        @minecraft_account = current_user.build_minecraft_account
        render :register_minecraft, locals: { correlation_id: correlation_id }
      end
    end
  end

  private

  def minecraft_params
    params.require(:minecraft_account).permit(:nickname, :password, :password_confirmation)
  end
end
