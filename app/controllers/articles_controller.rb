class ArticlesController < ApplicationController

  def index
    respond_to do |format|
      format.json
    end
  end

  def search
    respond_to do |format|
      format.json
    end
  end

end
