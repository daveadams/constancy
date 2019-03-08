# This software is public domain. No rights are reserved. See LICENSE for more information.

require 'spec_helper'

RSpec.describe Constancy::SyncTarget do
  describe '#local_items' do
    context 'using a yml file with deeply nested hashes' do
      let(:tgt) {
        Constancy::SyncTarget.new(
          base_dir: FIXTURE_DIR,
          config: {
            'type'   => 'file',
            'path'   => "nested_hashes.yml",
            'prefix' => 'config/nested'
          },
          imperium_config: Imperium::Configuration.new,
        )
      }

      it 'must flatten the nested hashes' do
        items = tgt.local_items
        expect(items.values).to all be_a String

        expect(items).to include({'one_key' => 'foo'})
        expect(items).to include({'nested_hash/two_key' => 'bar'})
        expect(items).to include({'nested_hash/nested_hash/three_key' => 'baz'})
        expect(items).to include({'nested_hash/nested_hash' => 'wat'})
      end
    end
  end
end
