namespace :segments do
  desc "Build segments bundle"
  task :build do
    unless system "yarn install && node build_segments_bundle.js"
      raise "Command node build_segments_bundle.js failed, ensure yarn is installed and `node build_segments_bundle.js` runs without errors"
    end
  end
end

if Rake::Task.task_defined?("css:build")
  Rake::Task["css:build"].enhance(["segments:build"])
end

if Rake::Task.task_defined?("test:prepare")
  Rake::Task["test:prepare"].enhance(["segments:build"])
elsif Rake::Task.task_defined?("db:test:prepare")
  Rake::Task["db:test:prepare"].enhance(["segments:build"])
end
