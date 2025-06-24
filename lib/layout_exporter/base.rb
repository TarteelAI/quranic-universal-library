module LayoutExporter
  class Base
    attr_reader :mushaf

    def initialize(mushaf_id:)
      @mushaf = Mushaf.find(mushaf_id)
    end

    protected
    def get_mushaf_file_name
      mapping = {
        "1": "qpc_v2",
        "2": "qpc_v1",
        "6": "indopak_15_lines",
        "17": "indopak_13_lines",
        "19": "qpc_v4"
      }

      mapping[@mushaf.id.to_s.to_sym]
    end
  end
end
