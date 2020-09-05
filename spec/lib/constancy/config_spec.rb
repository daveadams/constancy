# This software is public domain. No rights are reserved. See LICENSE for more information.

require 'spec_helper'

RSpec.describe Constancy::Config do
  describe '#only_valid_config_keys!' do
    context 'taking lists of valid configuration keys' do
      let(:keylists) {
        [
          %w( constancy vault consul sync ),
          %w( constancy vault vault.main vault.dev sync ),
          %w( vault.us-east-1 vault.b220300 ),
        ]
      }

      it 'accepts all valid key lists' do
        keylists.each do |keylist|
          expect(Constancy::Config.only_valid_config_keys!(keylist)).to be true
        end
      end
    end

    context 'taking lists containing invalid configuration keys' do
      let(:keylists) {
        [
          %w( constancy vault consul sync.banana ),
          %w( constancy vault vault.main vault._dev sync ),
          %w( vault.us-east-1 vault.220300 ),
          %w( volt console sink constancee ),
        ]
      }

      it 'raises an exception for invalid key lists' do
        keylists.each do |keylist|
          expect {
            Constancy::Config.only_valid_config_keys!(keylist)
          }.to raise_exception(Constancy::ConfigFileInvalid, /is not a valid configuration key/)
        end
      end
    end
  end
end
