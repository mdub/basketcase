# task :default => :publish
# 
# task :publish do
#   sh "scp -r dist/basketcase.rb dist/index.html mdub@rubyforge.org:/var/www/gforge-projects/basketcase/"
# end

require 'rubygems'
require 'hoe'
require './lib/basketcase.rb'

Hoe.new('basketcase', Basketcase::VERSION) do |p|
  p.developer('mdub', 'mdub@dogbiscuit.org')
end
