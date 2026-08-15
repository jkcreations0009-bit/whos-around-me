#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'xcodeproj'

root = Pathname.new(ENV.fetch('WHOS_AROUND_ME_ROOT', Pathname.new(__dir__).join('..').expand_path.to_s)).expand_path
app = root.join('apps', 'mobile')
ios = app.join('ios')
project_path = ios.join('Runner.xcodeproj')
raise 'Generated iOS Xcode project is missing.' unless project_path.directory?

environments = {
  'development' => 'com.dC0dez.Whosaroundme.dev',
  'test' => 'com.dC0dez.Whosaroundme.test',
  'staging' => 'com.dC0dez.Whosaroundme.staging',
  'production' => 'com.dC0dez.Whosaroundme'
}.freeze

base_types = {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release
}.freeze

project = Xcodeproj::Project.open(project_path.to_s)
runner = project.targets.find { |target| target.name == 'Runner' }
raise 'Runner target is missing.' unless runner

# Snapshot the generated base configuration objects before adding flavors.
project_bases = base_types.keys.to_h do |name|
  config = project.build_configurations.find { |item| item.name == name }
  raise "Project build configuration #{name} is missing." unless config
  [name, config]
end

target_bases = project.targets.to_h do |target|
  bases = base_types.keys.to_h do |name|
    config = target.build_configurations.find { |item| item.name == name }
    raise "Target #{target.name} build configuration #{name} is missing." unless config
    [name, config]
  end
  [target.uuid, bases]
end

def clone_configuration(destination, source)
  destination.build_settings = Marshal.load(Marshal.dump(source.build_settings))
  destination.base_configuration_reference = source.base_configuration_reference
end

environments.each do |environment, bundle_id|
  base_types.each do |base_name, type|
    flavored_name = "#{base_name}-#{environment}"

    project_config = project.build_configurations.find { |item| item.name == flavored_name }
    project_config ||= project.add_build_configuration(flavored_name, type)
    clone_configuration(project_config, project_bases.fetch(base_name))

    project.targets.each do |target|
      target_config = target.build_configurations.find { |item| item.name == flavored_name }
      target_config ||= target.add_build_configuration(flavored_name, type)
      clone_configuration(target_config, target_bases.fetch(target.uuid).fetch(base_name))
      next unless target.name == 'Runner'

      target_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
    end
  end
end

project.save

# CocoaPods must know how every custom build configuration maps to debug/release.
podfile = ios.join('Podfile')
raise 'Generated iOS Podfile is missing.' unless podfile.file?
pod_text = podfile.read
mapping_lines = [
  "  'Debug' => :debug,",
  "  'Profile' => :release,",
  "  'Release' => :release,"
]
environments.each_key do |environment|
  mapping_lines << "  'Debug-#{environment}' => :debug,"
  mapping_lines << "  'Profile-#{environment}' => :release,"
  mapping_lines << "  'Release-#{environment}' => :release,"
end
mapping = "project 'Runner', {\n#{mapping_lines.join("\n")}\n}"
pattern = /project 'Runner', \{.*?\n\}/m
raise 'Could not find Runner project configuration mapping in Podfile.' unless pod_text.match?(pattern)
podfile.write(pod_text.sub(pattern, mapping))

# Shared scheme names are the Flutter flavor names. Keep the generated Runner scheme
# as the canonical target/action template and only bind each action to flavored configs.
schemes_dir = project_path.join('xcshareddata', 'xcschemes')
template_path = schemes_dir.join('Runner.xcscheme')
raise 'Generated shared Runner.xcscheme is missing.' unless template_path.file?
template = template_path.read

environments.each_key do |environment|
  scheme = template.dup
  scheme.gsub!('buildConfiguration = "Debug"', "buildConfiguration = \"Debug-#{environment}\"")
  scheme.gsub!('buildConfiguration = "Profile"', "buildConfiguration = \"Profile-#{environment}\"")
  scheme.gsub!('buildConfiguration = "Release"', "buildConfiguration = \"Release-#{environment}\"")
  schemes_dir.join("#{environment}.xcscheme").write(scheme)
end

# Retain a machine-readable, non-secret reference for CI and future Firebase setup.
reference = ios.join('Flutter', 'WhosAroundMeEnvironmentIds.xcconfig')
reference.dirname.mkpath
reference.write(
  environments.map { |name, bundle_id| "WHOSAROUNDME_BUNDLE_ID_#{name.upcase}=#{bundle_id}" }.join("\n") + "\n"
)

puts 'Configured iOS development/test/staging/production schemes.'
environments.each { |name, bundle_id| puts "#{name}: #{bundle_id}" }
