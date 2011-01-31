# -*- ruby -*-

$LOAD_PATH << './lib'

require 'rubygems'
gem     'rjack-tarpit', '~> 1.2'
require 'rjack-tarpit'

require 'hooker/base'

t = RJack::TarPit.new( 'hooker', Hooker::VERSION )

t.specify do |h|
  h.developer( 'David Kellum', 'dek-oss@gravitext.com' )
  h.testlib = :minitest
  #FIXME: h.extra_deps     += [ [ 'rjack-slf4j',         '~> 1.6.1' ],
  #                             [ 'rjack-logback',       '~> 1.0.0' ] ]
  h.extra_dev_deps += [ [ 'minitest',            '>= 1.7.1', '< 2.1' ] ]
end

# Version/date consistency checks:

task :check_history_version do
  t.test_line_match( 'History.rdoc', /^==/, / #{ t.version } / )
end
task :check_history_date do
  t.test_line_match( 'History.rdoc', /^==/, /\([0-9\-]+\)$/ )
end

task :gem  => [ :check_history_version  ]
task :tag  => [ :check_history_version, :check_history_date ]
task :push => [ :check_history_version, :check_history_date ]

t.define_tasks
