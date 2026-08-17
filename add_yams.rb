require 'xcodeproj'

project_path = 'app-four.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Add package reference
pkg_ref = project.root_object.package_references.find { |p| p.respond_to?(:repositoryURL) && p.repositoryURL.include?('Yams') }
unless pkg_ref
  pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg_ref.repositoryURL = 'https://github.com/jpsim/Yams.git'
  pkg_ref.requirement = {
    'kind' => 'upToNextMajorVersion',
    'minimumVersion' => '5.0.0'
  }
  project.root_object.package_references << pkg_ref
end

# Add product dependency (app target only — tests reach Yams transitively
# through the host app via @testable import app_four)
target = project.targets.find { |t| t.name == 'app-four' }
product_dep = target.package_product_dependencies.find { |p| p.product_name == 'Yams' }
unless product_dep
  product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dep.package = pkg_ref
  product_dep.product_name = 'Yams'
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

project.save
puts "Added Yams package dependency successfully."
