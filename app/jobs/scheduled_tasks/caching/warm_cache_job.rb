module ScheduledTasks
  module Caching
    class WarmCacheJob < ScheduledTask
      def perform
        # Get the CMS mode that's set up for this instance
        cms_mode = ApplicationController.helpers.check_for_valid_cms_mode

        # Go through and get the articles for the current method. We throw away the response
        # because this will just set the cache keys

        # We're not passing in params, which means multiple pages and such won't be cached. What we care
        # about is speed right now. So that's fine for the moment. We could conceive of caching a few
        # pages at anytime, but that's for another time.
        case cms_mode
        when :occrp_joomla
          JoomlaOccrp.articles({})
        when :wordpress
          Wordpress.articles({})
        when :newscoop
          Newscoop.articles({})
        when :cins_codeigniter
          CinsCodeigniter.articles({})
        when :blox
          Blox.articles({})
        when :snworks
          SNWorksCEO.articles({})
        end
      end
    end
  end
end
