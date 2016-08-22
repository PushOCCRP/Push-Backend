module ApplicationHelper

	def sanitized_query query_string
	    sanitized_query = query_string.unpack("U*").map{|c| c<256 ? c.chr : nil}.join
	    return sanitized_query
	end
end
