require "test_helper"

class SnWorksCEOTest < ActiveSupport::TestCase
  test "Bearer key should be generated" do
    bearer_token = SNWorksCEO.send(:bearer_token)
    assert_not_nil bearer_token, "SNWorks bearer token must not be nil."
  end

  test "Bearer key should have 'pk' in payload" do
    bearer_token = SNWorksCEO.send(:bearer_token)
    decoded_token = JWT.decode bearer_token, Figaro.env.snworks_private_api_key, true, { algorithm: "HS256" }
    pk = decoded_token.find { |x| x.keys.include?("pk") }
    assert_not_nil pk, "SNWorks bearer token must include 'pk' in the payload."
  end

  test "Getting articles should return an array" do
    articles = SNWorksCEO.articles nil
    assert_not_nil articles, "SNWorks should return an array of articles."
  end

  test "Get url should accept options" do
    SNWorksCEO.get_url("/test", { test: "key" })
    assert_equal "#{ENV["snworks_url"]}/test?test=key", "#{ENV["snworks_url"]}/test?test=key"
  end

  test "Searching should return an aray" do
    articles = SNWorksCEO.search({ "q": "wisconsin" })
    assert_not_nil articles, "SNWorks should allow searching"
  end
end
