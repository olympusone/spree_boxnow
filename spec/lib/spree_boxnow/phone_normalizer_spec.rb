require 'spec_helper'

RSpec.describe SpreeBoxnow::PhoneNormalizer do
  describe '.call' do
    it 'converts a bare Greek number to E.164' do
      expect(described_class.call('6912345678')).to eq('+306912345678')
    end

    it 'leaves an already-international Greek number unchanged' do
      expect(described_class.call('+306912345678')).to eq('+306912345678')
    end

    it 'strips spaces and dashes' do
      expect(described_class.call('691 234 5678')).to eq('+306912345678')
      expect(described_class.call('691-234-5678')).to eq('+306912345678')
    end

    it 'uses the given country_iso to interpret a national-format number' do
      expect(described_class.call('07400123456', 'GB')).to eq('+447400123456')
    end

    it 'leaves a non-Greek international number unchanged regardless of country_iso' do
      expect(described_class.call('+447400123456', 'GR')).to eq('+447400123456')
    end

    it 'falls back to the raw input when the number cannot be validated' do
      expect(described_class.call('not-a-phone')).to eq('not-a-phone')
    end

    it 'returns an empty string for blank input' do
      expect(described_class.call(nil)).to eq('')
      expect(described_class.call('')).to eq('')
    end
  end
end
