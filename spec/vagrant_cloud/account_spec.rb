require 'vagrant_cloud'

describe VagrantCloud::Account do

  let (:account) { VagrantCloud::Account.new('my-username', 'my-token') }

  describe '#initialize' do
    it 'stores credentials' do
      expect(account.username).to eq('my-username')
      expect(account.access_token).to eq('my-token')
    end
  end

end
