Rails.application.config.content_security_policy do |policy|
  policy.connect_src :self, :http, "http://localhost:3035", "ws://localhost:3035" if Rails.env.development?
end
