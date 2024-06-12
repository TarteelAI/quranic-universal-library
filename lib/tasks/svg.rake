namespace :svg do
  task upsacle: :environment do
    # https://deepai.org/machine-learning-model/waifu2x
    # https://deepai.org/machine-learning-model/torch-srgan
    DEEPAI_API_KEY = '96590a88-adb3-4298-8807-ce35865b0b38'
    TIMEOUT = 1200
    require 'rest_client'

    Word.where(verse_id: 1).find_each do |word|
      next if !word.word? || File.exists?("data/words-data/corpus-data/images/w/rq-color-2x/#{word.location.gsub(':', '/')}.jpg")

      FileUtils.mkdir_p("data/words-data/corpus-data/images/w/rq-color-2x/#{word.verse_key.gsub(':', '/')}")

      source = "data/words-data/corpus-data/images/w/rq-color/#{word.location.gsub(':', '/')}.png"
      image = "data/words-data/corpus-data/images/w/rq-color-2x/#{word.location.gsub(':', '/')}.png"

      # detect image size
      #size = `identify -ping -format '%w %h' #{source}`
      #width, height = size.split(' ')

      # add 2px white space around the image
      #`convert -background transparent #{source} -gravity center -extent #{width.to_i+8}x#{height.to_i+8} #{image}`
      `convert #{source} -gravity center -background white -extent $(identify -format '%[fx:W+4]x%H' #{source}) #{image}`
      next
      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
        RestClient::Request.execute(
          method: :post,
          url: 'https://api.deepai.org/api/waifu2x',
          timeout: TIMEOUT,
          headers: { 'api-key': DEEPAI_API_KEY },
          payload: {
            image: File.new(image),
          }
        )
      end

      url = JSON.parse(response.body)['output_url']

      # AGAIN
      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
        RestClient::Request.execute(
          method: :post,
          url: 'https://api.deepai.org/api/waifu2x',
          timeout: TIMEOUT,
          headers: { 'api-key': DEEPAI_API_KEY },
          payload: {
            image: url,
          }
        )
      end

      url = JSON.parse(response.body)['output_url']

      # torch-srgan
      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
        RestClient::Request.execute(
          method: :post,
          url: 'https://api.deepai.org/api/torch-srgan',
          timeout: TIMEOUT,
          headers: { 'api-key': DEEPAI_API_KEY },
          payload: {
            image: url,
          }
        )
      end

      url = JSON.parse(response.body)['output_url']

      # Download the image
      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
        RestClient.get(url)
      end

      File.open("data/words-data/corpus-data/images/w/rq-color-2x/#{word.location.gsub(':', '/')}.jpg", "wb") do |file|
        file.puts response.body
      end

      puts word.location
    end
  end
end