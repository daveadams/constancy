# This software is public domain. No rights are reserved. See LICENSE for more information.

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'constancy'

SPEC_DIR = File.dirname(__FILE__)
FIXTURE_DIR = File.join(SPEC_DIR, 'fixtures')

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.color = true

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.profile_examples = 10

  config.order = :random
  Kernel.srand config.seed
end
