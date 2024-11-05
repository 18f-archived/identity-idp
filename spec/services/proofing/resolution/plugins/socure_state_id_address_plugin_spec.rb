require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::SocureStateIdAddressPlugin do
  subject(:plugin) do
    described_class.new
  end

  it 'includes StateIdAddressPlugin' do
    expect(described_class.ancestors).to(
      include(Proofing::Resolution::Plugins::StateIdAddressPlugin),
    )
  end

  describe '#sp_cost_token' do
    it 'returns socure_resolution' do
      expect(plugin.sp_cost_token).to eql(:socure_resolution)
    end
  end

  describe '#proofer' do
    before do
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
    end

    it 'returns a proofer' do
      expect(plugin.proofer).to be_a(Proofing::Socure::IdPlus::Proofer)
    end
  end
end
