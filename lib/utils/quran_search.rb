module Utils
  class QuranSearch
    def search(query)
      encoded_query = URI.encode_www_form_component(query.strip)

      response = RestClient.get("http://localhost:3001/api/qdc/search/quran?query=#{encoded_query}")
      JSON.parse(response.body)['result']
    rescue Exception => e
      {
        error: e.message
      }
    end
  end
end