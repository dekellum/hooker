#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived
#--
# Copyright (c) 2011 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You
# may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

TESTDIR = File.dirname( __FILE__ )

require File.join( TESTDIR, "setup" )

require 'hooker'

# An alternative entry point from top level
class AltEntry
  def self.configure
    yield Hooker
  end
end

class TestContext < MiniTest::Unit::TestCase
  def setup
    Hooker.log_with { |msg| puts; puts msg }
  end

  def teardown
    Hooker.send( :clear ) #private
  end

  def test_not_set
    assert_nil( Hooker.inject( :test_hook ) )

    assert_equal( :identity, Hooker.inject( :test_hook, :identity ) )
  end

  def test_no_arg_hook
    Hooker.add( :test ) { :returned }

    assert_equal( :returned, Hooker.inject( :test ) )
    assert_equal( :returned, Hooker.inject( :test, :ignored ) )
  end

  def test_chained_hook
    Hooker.with do |h|
      h.add( :test ) { |l| l << :a }
      h.add( :test ) { |l| l << :b }
    end

    assert_equal( [ :a, :b ], Hooker.inject( :test, [] ) )
  end

  def test_mutate
    Hooker.with do |h|
      h.add( :test ) { |h| h[ :prop ] = "a" }
      h.add( :test ) { |h| h[ :prop ] = "b" }
    end

    h = Hooker.mutate( :test, { :prop => "orig" } )

    assert_equal( "b", h[ :prop ] )
  end

  def test_check_not_applied

    Hooker.with do |h|
      h.add( :used )     { :returned }
      h.add( :not_used ) { flunk "first time" }
      h.add( :not_used ) { flunk "once more"  }
    end

    assert_equal( :returned, Hooker.inject( :used ) )

    not_used_keys = []
    not_used_calls = []
    Hooker.check_not_applied do |rkey, calls|
      not_used_keys << rkey
      not_used_calls += calls
    end

    assert_equal( [ :not_used ], not_used_keys )
    assert_equal( 2, not_used_calls.length )

    Hooker.log_not_applied
  end

  def test_load
    Hooker.load_file( File.join( File.dirname( __FILE__ ), 'config.rb' ) )
    assert_equal( :returned, Hooker.inject( :test ) )
  end

  def test_load_with_alt_entry
    Hooker.load_file( File.join( File.dirname( __FILE__ ), 'alt_entry.rb' ) )
    assert_equal( :returned, Hooker.inject( :test ) )
  end

end
