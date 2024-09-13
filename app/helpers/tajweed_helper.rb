module TajweedHelper
  def tajweed_rule_options_for_select
    documentation = TajweedRules.documentation

    TajweedRules.rules.map do |r, i|
      rule = documentation[r.to_sym]

      [
        r,
        i,
        {
          data: {
            description: "<div class='d-flex align-items-center'><span class='tajwee-rule-icon me-2'>#{rule[:font_code]}</span> <span>#{rule[:name]}</span></div>"
          }
        }
      ]
    end
  end
end