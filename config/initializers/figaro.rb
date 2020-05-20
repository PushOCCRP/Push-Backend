Figaro.require_keys("cms_mode", "title")

Figaro.require_keys("host") if !ENV["proxy_images"].blank?
auth = ENV["auth_enabled"].downcase == true if !ENV["auth_enabled"].blank?

case ENV["cms_mode"]
when "occrp-joomla"
  Figaro.require_keys("occrp_joomla_url")
when "wordpress"
  Figaro.require_keys("wordpress_url")
when "newscoop"
  Figaro.require_keys("newscoop_url")
  Figaro.require_keys("newscoop_client_id")
  Figaro.require_keys("newscoop_client_secret")
when "cins-codeigniter"
  Figaro.require_keys("codeigniter_url")
when "blox"
  Figaro.require_keys("blox_url")
  Figaro.require_keys("blox_publication_name")
  Figaro.require_keys("blox_eedition_key")
  Figaro.require_keys("blox_eedition_secret")
  Figaro.require_keys("blox_editorial_key")
  Figaro.require_keys("blox_editorial_secret")
  if auth == true
    Figaro.require_keys("blox_user_key")
    Figaro.require_keys("blox_user_secret")
  end

  # Blox seems to only support one language at a time.
  languages = ENV["languages"].delete('"').split(",")
  raise "Blox only supports one language at a time right now" if languages.count > 1
when "snworks"
  # Figaro.require_keys["xxxxx"]
else
  raise "No valid cms mode, please fix the environment variable \"cms_mode\""
end

if !ENV["developer_mode"] || ENV["developer_mode"].length > 0
  ENV["developer_mode"] = "false"
end
