# frozen_string_literal: true

class SubscriptionUser < ApplicationRecord
  before_create :generate_api_key

  def self.authenticate(username, api_key)
    user = find(username: username)
    return false, User.new if user.nil?

    authenticated = user.api_key == api_key
    [authenticated, user]
  end

  def generate_api_key
    self.api_key = SecureRandom.hex(12)
  end
end
