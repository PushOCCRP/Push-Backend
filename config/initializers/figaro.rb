Figaro.require_keys("cms_mode")

case ENV['cms_mode']
  when "occrp-joomla"
  	Figaro.require_keys("occrp_joomla_url")
  when "wordpress"
    Figaro.require_keys("wordpress_url")
  when "newscoop"
    Figaro.require_keys("newscoop_url")
    Figaro.require_keys("newscoop_client_id")
    Figaro.require_keys("newscoop_client_secret")
  else
  	raise "No valid cms mode, please fix the environment variable \"cms_mode\""
end