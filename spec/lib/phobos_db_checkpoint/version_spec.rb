require 'spec_helper'

RSpec.describe 'PhobosDBCheckpoint::VERSION' do
  it 'has a version' do
    expect(PhobosDBCheckpoint::VERSION).to_not be_nil
  end

  it 'the latest version is described in CHANGELOG' do
    expect(File.read('CHANGELOG.md').match(/^## (\d+.\d+.\d+)/)[1]).to eq(PhobosDBCheckpoint::VERSION)
  end
end
