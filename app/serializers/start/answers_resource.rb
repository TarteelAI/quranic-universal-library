# frozen_string_literal: true

module Start
  # The answers of a guided setup (GuidedSetup::Answers), the steps they answer and the step to
  # open.
  class AnswersResource < ApplicationResource
    typelize goals: [:string, { multi: true }], platforms: [:string, { multi: true }],
             features: [:string, { multi: true }], scripts: [:string, { multi: true }],
             languages: [:string, { multi: true }],
             answered: [:string, { multi: true, enum: GuidedSetup::STEPS }], step: :number
    attributes :goals, :platforms, :features, :scripts, :languages, :answered, :step
  end
end
