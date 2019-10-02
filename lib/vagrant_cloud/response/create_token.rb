module VagrantCloud
  class Response
    class CreateToken < Response
      attr_required :token, :token_hash, :created_at, :description
    end
  end
end
