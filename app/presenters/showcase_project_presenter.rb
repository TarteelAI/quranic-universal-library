class ShowcaseProjectPresenter < ApplicationPresenter
  def meta_title
    case action_name
    when 'new', 'create'
      'Submit your project — Showcase'
    when 'edit', 'update'
      'Edit your project — Showcase'
    else
      'Showcase — Projects built with QUL'
    end
  end

  def meta_description
    'Apps, libraries, APIs and models built by the community with Quranic Universal Library resources. Find inspiration and submit your own project.'
  end

  def meta_keywords
    'built with QUL, Quran apps, Quran app showcase, Quran developer projects, Quran API projects, Quran libraries, Islamic apps, Quranic Universal Library community'
  end
end
