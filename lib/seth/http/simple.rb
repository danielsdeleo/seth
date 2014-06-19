require 'seth/http'
require 'seth/http/authenticator'
require 'seth/http/decompressor'


class Seth
  class HTTP

    class Simple < HTTP

      use Decompressor
      use CookieManager

      # ValidateContentLength should come after Decompressor
      # because the order of middlewares is reversed when handling
      # responses.
      use ValidateContentLength

    end
  end
end
