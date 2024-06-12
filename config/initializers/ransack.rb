Ransack.configure do |config|
  config.add_predicate 'jcont', arel_predicate: 'contains', formatter: proc { |v|
    Arel::Nodes.build_quoted v.strip.split(',').to_json
  }
end
