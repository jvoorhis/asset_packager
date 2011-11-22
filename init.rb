$:.unshift(File.dirname(__FILE__) + '/lib')

require 'base64'

Base64.module_eval do
  unless defined?(urlsafe_encode64)
    def urlsafe_encode64(bin)
      [bin].pack("m0").tr("+/", "-_").chomp
    end
  end
end
 
require 'asset_packager'
require 'javascript_packager'
require 'css_packager'

require 'rails_helper' if defined?(Rails)
