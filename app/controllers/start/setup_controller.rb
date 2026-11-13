# frozen_string_literal: true

module Start
  # The guided setup while the `start` page group is on (PageGroups). There is no old page: with
  # the group off, /start is a 404. The answers are in the query string (GuidedSetup::Answers),
  # so a setup can be resumed and shared.
  #
  # /start opens the flow at the first unanswered step. Its last step links to the results: the
  # catalog URL with the answers (/resources?goal=…), served here while the `catalog` group is on
  # too, with the needs checklist and the resources for each need.
  class SetupController < InertiaController
    # The cards each section of the results shows; its catalog link lists the rest.
    CARDS = 6

    # A checklist item (GuidedSetup::Item) with its label and its catalog search.
    Section = Data.define(:item, :label, :search)

    def show
      @languages = GuidedSetup.languages
      @answers = GuidedSetup::Answers.from(request.query_parameters, languages: @languages.map(&:key))

      render_inertia 'start/SetupPage', meta: page_meta(
        title: 'Start building - QUL',
        description: 'Answer five questions about the app you are building, and see the Quran data it needs: ' \
                     'scripts, fonts, layouts, translations, recitations and more.',
      )
    end

    def results
      @languages = GuidedSetup.languages
      @answers = GuidedSetup::Answers.from(request.query_parameters, languages: @languages.map(&:key))
      return redirect_to start_setup_path(request.query_parameters) if @answers.goals.empty?

      @result = GuidedSetup.result(@answers)
      @sections = @result.items.map { |item| section(item) }

      render_inertia 'start/SetupResultsPage', meta: page_meta(
        title: 'Resources for your app - QUL',
        description: 'The Quran data your app needs, from the answers of the guided setup.',
      )
    end

    private

    def section(item)
      label = item.need.label
      label += " in #{@languages.find { |language| language.key == item.language }.name}" if item.language
      search = Catalog::SearchQuery.new(Catalog::SearchFilters.from(item.filters), per_page: CARDS).call
      Section.new(item: item, label: label, search: search)
    end
  end
end
