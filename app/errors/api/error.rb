module Api
  # Base class for errors the v1 API turns into a JSON response rather than a 500.
  class Error < StandardError
  end
end
