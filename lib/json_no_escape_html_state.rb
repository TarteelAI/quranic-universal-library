class JsonNoEscapeHtmlState < JSON::State
  def generate_string(value, _)
    value.to_s
  end
end