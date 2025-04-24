
module V1
  class UserController < ApplicationController
    def index
      @users = User.all
    end

    def show
      @user = User.find(params[:id]).first
    end
  end
end
