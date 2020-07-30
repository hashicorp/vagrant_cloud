module VagrantCloud
  class Response < Data::Immutable
    autoload :CreateToken, "vagrant_cloud/response/create_token"
    autoload :Request2FA, "vagrant_cloud/response/request_2fa"
    autoload :Search, "vagrant_cloud/response/search"
  end
end
