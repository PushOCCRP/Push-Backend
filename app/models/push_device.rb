class PushDevice < ActiveRecord::Base
  
  module Status
    ACTIVE = 0
    DISABLED = 1
    SANDBOX = 2
    UNIQUSH = 3
  end

end
