$LOAD_PATH.unshift File.expand_path('lib', __dir__)

require 'bundler/gem_tasks'
require 'rubocop/rake_task'

RuboCop::RakeTask.new

Dir.glob(File.expand_path('tasks/*.rake', __dir__)).each do |task|
  load task
end

task default: [:spec, :rubocop]
