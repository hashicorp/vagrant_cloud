require 'spec_helper'
require 'vagrant_cloud'

module VagrantCloud
  describe Box do

    let (:account) { Account.new('my-acc', 'my-token') }

    describe '#initialize' do
      it 'stores data' do
        data = {
          'description_markdown' => 'desc-markdown',
          'short_description' => 'desc-short',
          'private' => false,
          'versions' => [],
        }
        box = Box.new(account, 'foo', data)

        expect(box.account).to eq(account)
        expect(box.data).to eq(data)
        expect(box.name).to eq('foo')
        expect(box.description).to eq('desc-markdown')
        expect(box.description_short).to eq('desc-short')
        expect(box.private).to eq(false)
      end
    end

    describe '.versions' do
      it 'returns version in the right order' do
        box = Box.new(account, 'foo', {
            'versions' => [
              {'number' => '2.0'},
              {'number' => '1.0'},
            ],
          })

        expect(box.versions.length).to eq(2)
        expect(box.versions[0].number).to eq('1.0')
        expect(box.versions[1].number).to eq('2.0')
      end
    end

  end
end
