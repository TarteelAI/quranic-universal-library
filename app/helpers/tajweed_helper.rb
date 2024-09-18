module TajweedHelper
  def tajweed_rule_options_for_select(tajweed, display: 'index')
    documentation = tajweed.documentation
    show_rule_name_as_label = display  == 'name'

    tajweed.rules.map do |r, i|
      rule = documentation[r.to_sym]

      [
        r,
        show_rule_name_as_label ? r : i,
        {
          data: {
            description: "<div class='d-flex align-items-center'><span class='tajwee-rule-icon me-2'>#{rule[:font_code]}</span> <span>#{rule[:name]}</span></div>"
          }
        }
      ]
    end
  end
end