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
  class QuranGrammarHtmlGenerator < OpenaiAgent
    def generate(
      english_term:,
      arabic_term:,
      output_language:,
      term_type:,
      corpus_link: nil
    )
      generate_response(
        Corpus::QuranGrammarPrompt::SYSTEM_PROMPT,
        Corpus::QuranGrammarPrompt.user_prompt(
          english: english_term,
          arabic: arabic_term,
          term_type: term_type,
          output_language: output_language,
          corpus_link: corpus_link
        )
      )
    end
  end
end