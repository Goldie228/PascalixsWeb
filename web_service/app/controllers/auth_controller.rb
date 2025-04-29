class AuthController < ApplicationController  
  def login
    if current_user
      redirect_to localized_root_path
    end
  end
  
  def logout
    session[:user_id] = nil
  end

  def discord
  end
end 