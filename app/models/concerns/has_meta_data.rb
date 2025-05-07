module HasMetaData
  extend ActiveSupport::Concern
  def meta_value(key)
    key = format_meta_key(key)
    fetch_metadata[key]
  end

  def meta_data=(val)
    json = if val.is_a? String
             Oj.safe_load(val)
           else
             val
           end

    json.keys.each do |key|
      formatted_key = format_meta_key(key)

      if formatted_key != key
        json[formatted_key] = json[key]
        json.delete(key)
      end
    end

    super json
  end

  def set_meta_value(key, val)
    key = format_meta_key(key)

    meta_data = fetch_metadata
    meta_data[key] = val
  end

  def delete_meta_value(key)
    key = format_meta_key(key)
    meta_data = fetch_metadata

    meta_data.delete(key)
  end

  def set_meta_value!(key, val)
    set_meta_value(key, val)
    save
  end

  protected

  def fetch_metadata
    meta_data || {}
  end
end