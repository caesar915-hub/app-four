require 'xcodeproj'

project_path = 'app-four.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Add package reference
pkg_ref = project.root_object.package_references.find { |p| p.respond_to?(:repositoryURL) && p.repositoryURL.include?('swift-huggingface') }
unless pkg_ref
  pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg_ref.repositoryURL = 'https://github.com/huggingface/swift-huggingface.git'
  pkg_ref.requirement = {
    'kind' => 'upToNextMajorVersion',
    'minimumVersion' => '0.9.0'
  }
  project.root_object.package_references << pkg_ref
end

# Add product dependency
target = project.targets.find { |t| t.name == 'app-four' }
product_dep = target.package_product_dependencies.find { |p| p.product_name == 'HuggingFace' }
unless product_dep
  product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dep.package = pkg_ref
  product_dep.product_name = 'HuggingFace'
  target.package_product_dependencies << product_dep
end

# Link the framework
frameworks_build_phase = target.frameworks_build_phase
build_file = frameworks_build_phase.files.find { |f| f.product_ref == product_dep }
unless build_file
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dep
  frameworks_build_phase.files << build_file
end

# Do the same for tests target
test_target = project.targets.find { |t| t.name == 'app-fourTests' }
test_product_dep = test_target.package_product_dependencies.find { |p| p.product_name == 'HuggingFace' }
unless test_product_dep
  test_product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  test_product_dep.package = pkg_ref
  test_product_dep.product_name = 'HuggingFace'
  test_target.package_product_dependencies << test_product_dep
end

test_frameworks_build_phase = test_target.frameworks_build_phase
test_build_file = test_frameworks_build_phase.files.find { |f| f.product_ref == test_product_dep }
unless test_build_file
  test_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  test_build_file.product_ref = test_product_dep
  test_frameworks_build_phase.files << test_build_file
end

project.save
puts "Added HuggingFace package dependency successfully."
