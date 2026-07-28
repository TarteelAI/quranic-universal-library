class MaintenanceMode
  FLAG_PATH = Rails.root.join("tmp", "maintenance.txt")

  class << self
    def on?
      File.exist?(FLAG_PATH)
    end

    def on!
      FileUtils.mkdir_p(FLAG_PATH.dirname)
      FileUtils.touch(FLAG_PATH)
      true
    end

    def off!
      FileUtils.rm_f(FLAG_PATH)
      false
    end
  end
end