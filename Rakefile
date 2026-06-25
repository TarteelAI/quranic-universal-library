# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks

# Load rake tasks for qul-scripts
Dir.glob(File.expand_path('qul-scripts/**/*.rake', __dir__)).sort.each { |task| load task }
