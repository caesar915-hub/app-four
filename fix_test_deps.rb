require 'xcodeproj'
project = Xcodeproj::Project.open('app-four.xcodeproj')
test_target = project.targets.find { |t| t.name == 'app-fourTests' }

puts "Target: #{test_target.name}"

# Remove from framework build phase
test_target.frameworks_build_phase.files.dup.each do |file|
  if file.display_name.include?("MLXLLM") || file.display_name.include?("HuggingFace") || file.display_name.include?("Hub") || file.display_name.include?("Tokenizers")
    puts "Removing #{file.display_name} from frameworks build phase"
    test_target.frameworks_build_phase.remove_build_file(file)
  end
end

# Remove from target dependencies
test_target.dependencies.dup.each do |dep|
  if dep.display_name.include?("MLXLLM") || dep.display_name.include?("HuggingFace") || dep.display_name.include?("Hub") || dep.display_name.include?("Tokenizers")
    puts "Removing #{dep.display_name} from dependencies"
    test_target.dependencies.delete(dep)
  end
end

project.save
puts "Done"
