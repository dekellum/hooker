#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived
#--
# Copyright (c) 2011-2015 David Kellum
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
require 'thread'

# An alternative entry point from top level
class Chaplain
  def self.configure( &block )
    Hooker.with( :church, &block )
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

  def test_setup_method
    Hooker.setup_test { :returned } # via method_missing
    assert_equal( :returned, Hooker.inject( :test ) )
  end

  def test_not_setup_missing
    assert_raises( NoMethodError ) do
      Hooker.bogus_method
    end
  end

  def test_apply
    Hooker.with do |h|
      h.add( :test ) { |hsh| hsh[ :prop ] = "a" }
      h.add( :test ) { |hsh| hsh[ :prop ] = "b" }
    end

    h = Hooker.apply( :test, { :prop => "orig" } )

    assert_equal( "b", h[ :prop ] )
  end

  def test_merge
    Hooker.add( :test ) { { :a => 1, :b => 2                   } }
    Hooker.add( :test ) { {                   :c => 3          } }

    h = Hooker.merge( :test,
                          { :a => 0,                   :d => 4 } )
    assert_equal( h,      { :a => 1, :b => 2, :c => 3, :d => 4 } )
  end

  def test_check_not_applied

    Hooker.with( :test_scope ) do |h|
      h.add( :used )     { :returned }
      h.add( :not_used ) { flunk "first time" }
      h.add( :not_used ) { flunk "once more"  }
    end

    assert_equal( :returned,
                  Hooker.inject( [ :test_scope, :used ] ) )

    not_used_keys = []
    not_used_calls = []
    Hooker.check_not_applied do |rkey, calls|
      not_used_keys << rkey
      not_used_calls += calls
    end

    assert_equal( [ [ :test_scope, :not_used ] ], not_used_keys )
    assert_equal( 2, not_used_calls.length )
    not_used_calls.each_with_index do |cl, i|
      assert_match( /test_check_not_applied/, cl, i )
    end

    Hooker.log_not_applied
  end

  def test_check_not_applied_if_added_after

    Hooker.with( :test_scope ) do |h|
      assert_nil( h.inject( :not_used ) )
      h.add( :not_used ) { :returned }

      not_used_keys = []
      not_used_keys = Hooker.check_not_applied do |rkey, calls|
        not_used_keys << rkey
      end
      assert_equal( [ [:test_scope, :not_used] ], not_used_keys )
    end

  end

  def test_load
    Hooker.load_file( File.join( TESTDIR, 'config.rb' ) )
    assert_equal( :returned, Hooker.inject( :test ) )
  end

  def test_load_with_alt_entry
    Hooker.load_file( File.join( TESTDIR, 'alt_entry.rb' ) )
    assert_equal( :returned, Hooker.inject( [ :church, :test ] ) )
  end

  def test_load_dir_error
    assert_raises( Errno::EISDIR ) do
      Hooker.load_file( File.join( TESTDIR, 'test_load_dir' ) )
    end
  end

  def test_threaded_with
    Hooker.with( :t1 ) { |h| h.add( :common ) { :t1 } }
    Hooker.with( :t2 ) { |h| h.add( :common ) { :t2 } }

    threads = 11.times.map do |i|
      Thread.new( i.even? ? :t1 : :t2 ) do |scope|
        Hooker.with( scope ) do
          sleep( rand * 0.100 )
          Hooker.inject( :common )
        end
      end
    end

    11.times do |i|
      assert_equal( i.even? ? :t1 : :t2, threads[i].value, "thread #{i}" )
    end
  end

end
