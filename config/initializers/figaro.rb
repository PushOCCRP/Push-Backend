Figaro.require_keys("cms_mode", "title")

if(!ENV['proxy_images'].blank?)
  Figaro.require_keys("host")
end

case ENV['cms_mode']
  when "occrp-joomla"
  	Figaro.require_keys("occrp_joomla_url")
  when "wordpress"
    Figaro.require_keys("wordpress_url")
  when "newscoop"
    Figaro.require_keys("newscoop_url")
    Figaro.require_keys("newscoop_client_id")
    Figaro.require_keys("newscoop_client_secret")
  when "cins-codeignitor"
    Figaro.require_keys("cins_codeignitor_url")
  else
  	raise "No valid cms mode, please fix the environment variable \"cms_mode\""
end

if(!ENV['developer_mode'] || ENV['developer_mode'].length > 0)
  ENV['developer_mode'] = "false"
end