class Drupal < CMS
    polymorphic:true


	def self.articles params
	byebug
		data = '{
       "is_claimed":true,
       "rating":3.5,
       "mobile_url":"http://m.yelp.com/biz/rudys-barbershop-seattle"
      }'
         result = JSON.parse(data)
     return result.to_json
	end
end
