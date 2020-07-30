$LOAD_PATH.unshift File.expand_path('lib', __dir__)

require 'bundler/gem_tasks'

Dir.glob(File.expand_path('tasks/*.rake', __dir__)).each do |task|
  load task
end

task default: [:spec]
