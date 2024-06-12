class Hash
  def with_defaults_values(defaults)
    merge(defaults) { |_key, old, new| old.nil? ? new : old }
  end

  def with_defaults_values(defaults)
    merge!(defaults) { |_key, old, new| old.nil? ? new : old }
  end
end
