# Usage
=begin
c= Corpus::QuranGrammarHtmlGenerator.new
result =c.generate!(
  english_term: 'Adjectives',
  arabic_term: 'صفة',
  output_language: 'English',
  corpus_link: 'https://corpus.quran.com/documentation/adjective.jsp'
)
=end

module Corpus
  class QuranGrammarHtmlGenerator
    def generate(
      english_term:,
      arabic_term:,
      output_language:,
      term_type:,
      corpus_link: nil
    )
      uri = URI('https://api.openai.com/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{open_ai_key}"

      request.body = {
        model: 'gpt-4.1',
        messages: [
          { role: 'system',
            content: Corpus::QuranGrammarPrompt::SYSTEM_PROMPT
          },
          {
            role: 'user',
            content: Corpus::QuranGrammarPrompt.user_prompt(
              english: english_term,
              arabic: arabic_term,
              term_type: term_type,
              output_language: output_language,
              corpus_link: corpus_link
            )
          }
        ],
        temperature: 0.2
      }.to_json

      response = http.request(request)

      if response.code == '200'
        result = JSON.parse(response.body)
        translated = result.dig('choices', 0, 'message', 'content')
        translated&.strip
      else
        puts("OpenAI API error: #{response.code}")
        puts("Response: #{response.body}")
        nil
      end
    rescue => e
      puts("Failed to generate response: #{e.message}")
      nil
    end

    private

    def open_ai_key
      ENV.fetch("OPENAI_API_KEY") do
        raise("OPENAI_API_KEY environment variable is not set")
      end
    end
  end
end