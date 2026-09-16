# frozen_string_literal: true

# Stand-alone unit test for HealthCheck::Utils.check_migrations. Does NOT use
# the plugin-mode test_helper.rb (which requires a Rails app), so it can be run
# in isolation via `rake test:unit` or `ruby test/unit/utils_migration_check_test.rb`.

$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)

require 'minitest/autorun'
require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/class/attribute_accessors'

# Minimal ActiveRecord stub so the check has something to interrogate without
# booting Rails. Individual tests decide which of the check_*_pending! methods
# to expose on ActiveRecord::Migration.
module ActiveRecord
  class Migration; end
  PendingMigrationError = Class.new(StandardError) unless defined?(PendingMigrationError)
end

# Predefine the error class before requiring utils, so utils.rb resolves the
# constant into the HealthCheck module we control here.
module HealthCheck
  UnsupportedActiveRecordError = Class.new(StandardError) unless defined?(UnsupportedActiveRecordError)
end

require 'health_check/utils'

class UtilsMigrationCheckTest < Minitest::Test
  def setup
    reset_migration_stubs
  end

  def teardown
    reset_migration_stubs
  end

  def test_prefers_check_all_pending_when_available
    invocations = []
    stub_migration_method(:check_all_pending!) { invocations << :check_all_pending! }
    stub_migration_method(:check_pending!)     { invocations << :check_pending! }

    result = HealthCheck::Utils.check_migrations

    assert_nil result
    assert_equal [:check_all_pending!], invocations,
                 'Rails 7.1+ path must be preferred over the legacy check_pending!'
  end

  def test_falls_back_to_check_pending_on_older_rails
    invocations = []
    stub_migration_method(:check_pending!) { invocations << :check_pending! }
    # check_all_pending! deliberately not defined.

    result = HealthCheck::Utils.check_migrations

    assert_nil result
    assert_equal [:check_pending!], invocations
  end

  def test_returns_pending_migration_error_message_from_check_all_pending
    stub_migration_method(:check_all_pending!) do
      raise ActiveRecord::PendingMigrationError, 'Migrations are pending. Run `bin/rails db:migrate`.'
    end

    result = HealthCheck::Utils.check_migrations

    assert_equal 'Migrations are pending. Run `bin/rails db:migrate`.', result
  end

  def test_returns_pending_migration_error_message_from_check_pending
    stub_migration_method(:check_pending!) do
      raise ActiveRecord::PendingMigrationError, 'legacy pending message'
    end

    result = HealthCheck::Utils.check_migrations

    assert_equal 'legacy pending message', result
  end

  def test_raises_when_neither_entry_point_is_available
    error = assert_raises(HealthCheck::UnsupportedActiveRecordError) do
      HealthCheck::Utils.check_migrations
    end

    assert_match(/check_all_pending!/, error.message)
    assert_match(/check_pending!/,     error.message)
  end

  def test_raises_when_active_record_migration_is_not_defined
    saved_ar = ActiveRecord
    Object.send(:remove_const, :ActiveRecord)

    error = assert_raises(HealthCheck::UnsupportedActiveRecordError) do
      HealthCheck::Utils.check_migrations
    end

    assert_match(/ActiveRecord::Migration is not defined/, error.message)
  ensure
    Object.const_set(:ActiveRecord, saved_ar) if saved_ar && !Object.const_defined?(:ActiveRecord)
  end

  def test_process_checks_surfaces_pending_migration_message
    stub_migration_method(:check_all_pending!) do
      raise ActiveRecord::PendingMigrationError, 'pending!'
    end

    result = HealthCheck::Utils.process_checks('migration')

    assert_includes result, 'pending!'
  end

  def test_process_checks_surfaces_unsupported_error_message
    # Neither method defined => raises UnsupportedActiveRecordError, which the
    # outer rescue in process_checks converts to the returned error string.
    result = HealthCheck::Utils.process_checks('migration')

    assert_match(/check_all_pending!/, result)
  end

  private

  def stub_migration_method(name, &block)
    ActiveRecord::Migration.define_singleton_method(name, &block)
  end

  def reset_migration_stubs
    [:check_all_pending!, :check_pending!].each do |name|
      meta = ActiveRecord::Migration.singleton_class
      meta.send(:remove_method, name) if meta.instance_methods(false).include?(name)
    end
  end
end
