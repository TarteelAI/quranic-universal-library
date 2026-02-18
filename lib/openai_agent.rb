class OpenaiAgent
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  DEFAULT_MODEL = 'gpt-5-mini' # 'gpt-4.1'

  def generate_response(system_message, prompt, model: DEFAULT_MODEL, temperature: 0.7)
    http, request = build_agent

    request.body = {
      model: model,
      messages: [
        { role: 'system',
          content: system_message
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: temperature # Lower temperature for more focused responses
    }.to_json

    response = http.request(request)
    parse_response(response)
  rescue => e
    puts("Failed to generate response: #{e.message}")
    nil
  end

  protected

  def parse_response(response)
    if response.code == '200'
      result = JSON.parse(response.body)
      result.dig('choices', 0, 'message', 'content')
    else
      puts("OpenAI API error: #{response.code}")
      puts("Response: #{response.body}")
      nil
    end
  end

  def build_agent
    uri = URI(OPENAI_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{open_ai_key}"

    [http, request]
  end

  def open_ai_key
    ENV.fetch("OPENAI_API_KEY") do
      raise("OPENAI_API_KEY environment variable is not set")
    end
  end
end