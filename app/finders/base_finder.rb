class BaseFinder
  attr_reader :locale

  def initialize(locale: )
    @locale = locale
  end
end