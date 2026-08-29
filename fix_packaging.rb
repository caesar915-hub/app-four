require 'xcodeproj'

# One-time packaging fix:
# - replace the absolute file:// remote ref to Packages/mlx-swift-examples with
#   the vendored local package Packages/MLXLibraries (CI-safe)
# - drop the unused direct remote refs: swift-transformers (arrives transitively
#   via MLXLibraries) and swift-huggingface (zero app-code imports)
# - unlink the unused HuggingFace product from app + tests targets

project_path = 'app-four.xcodeproj'
project = Xcodeproj::Project.open(project_path)

refs = project.root_object.package_references

# 1. Remove remote package references that must go.
refs.delete_if do |p|
  next false unless p.respond_to?(:repositoryURL)
  url = p.repositoryURL.to_s
  url.include?('mlx-swift-examples') || url.include?('swift-huggingface') || url.include?('swift-transformers')
end

# 2. Add the vendored local package reference.
unless refs.any? { |p| p.respond_to?(:relative_path) && p.relative_path == 'Packages/MLXLibraries' }
  local_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  local_ref.relative_path = 'Packages/MLXLibraries'
  refs << local_ref
end

# 3. Fix product dependencies on both targets.
%w[app-four app-fourTests].each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  next unless target

  # Remove HuggingFace product dependency + its framework link.
  huggingface_deps = target.package_product_dependencies.select { |d| d.product_name == 'HuggingFace' }
  huggingface_deps.each do |dep|
    target.frameworks_build_phase.files.dup.each do |bf|
      if bf.respond_to?(:product_ref) && bf.product_ref == dep
        target.frameworks_build_phase.files.delete(bf)
        bf.remove_from_project
      end
    end
    target.package_product_dependencies.delete(dep)
    dep.remove_from_project
  end

  # Repoint MLXLLM to the vendored local package (local refs carry no `package`).
  target.package_product_dependencies.each do |dep|
    next unless dep.product_name == 'MLXLLM'
    dep.package = nil
  end
end

project.save
puts "Packaging fix applied."
