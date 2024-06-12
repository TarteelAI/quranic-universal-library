module Kernel
  def with_rescue_retry(exceptions, on_exception: nil, retries: 5, raise_exception_on_limit: true)
    try = 0

    begin
      yield try
    rescue *exceptions => exc
      on_exception.call(exc) if on_exception
      sleep 2
      try += 1
      try <= retries ? retry : raise_exception_on_limit && raise
    end
  end
end