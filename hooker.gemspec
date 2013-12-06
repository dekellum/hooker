# -*- ruby -*-

gem 'rjack-tarpit', '~> 2.1'
require 'rjack-tarpit/spec'

RJack::TarPit.specify do |s|
  require 'hooker/base'

  s.version = Hooker::VERSION

  s.add_developer( 'David Kellum', 'dek-oss@gravitext.com' )

  s.depend 'minitest', '~> 4.7.4', :dev
end
