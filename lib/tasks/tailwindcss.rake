# Overrides tailwindcss-rails' watch task to stop it exiting immediately under foreman (bin/dev).
Rake::Task["tailwindcss:watch"].clear if Rake::Task.task_defined?("tailwindcss:watch")

namespace :tailwindcss do
  desc "Watch and build Tailwind CSS on file changes (stays alive under bin/dev)"
  task watch: :environment do |_, args|
    debug = args.extras.include?("debug")
    poll = args.extras.include?("poll")
    always = args.extras.include?("always")
    command = Tailwindcss::Commands.watch_command(always: always, debug: debug, poll: poll)
    puts command.inspect if args.extras.include?("verbose")

    IO.popen(command, "r+") do |io|
      IO.copy_stream(io, $stdout)
    end
  rescue Interrupt
    puts "Received interrupt, exiting tailwindcss:watch" if args.extras.include?("verbose")
  end
end
