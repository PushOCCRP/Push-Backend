module Rearrangeable
  extend ActiveSupport::Concern

  module ClassMethods
    # Rearrange articles so the first has an image. If none do, then return the original array
    def rearrange_articles_for_images(articles)
      article_with_image = articles.find do |article|
        logger.debug "Checking article #{article} for images"
        article["images"].count > 0 || article[:header_image].nil? == false
      end

      # Because I'm a good CS student I make sure we don't do unncessary array modification
      return articles if article_with_image.nil? || article_with_image == articles.first

      articles.delete(article_with_image)
      articles.unshift(article_with_image)

      articles
    end
  end
end
