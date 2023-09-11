Pod::Spec.new do |s|
  s.name             = 'AppCheckCore'
  s.version          = '0.1.0-alpha.9'
  s.summary          = 'App Check Core SDK.'

  s.description      = <<-DESC
  SDK for anti-abuse compatibility.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/google/app-check.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '11.0'
  osx_deployment_target = '10.13'
  tvos_deployment_target = '12.0'
  watchos_deployment_target = '6.0'

  s.swift_version = '5.5'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  base_dir = "AppCheckCore/"

  s.source_files = [
    base_dir + 'Sources/**/*.[mh]',
  ]
  s.public_header_files = base_dir + 'Sources/Public/AppCheckCore/*.h'

  s.ios.weak_framework = 'DeviceCheck'
  s.osx.weak_framework = 'DeviceCheck'
  s.tvos.weak_framework = 'DeviceCheck'

  s.dependency 'PromisesObjC', '~> 2.3'
  s.dependency 'GoogleUtilities/Environment', '~> 7.11'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = [
      base_dir + 'Tests/Unit/**/*.[mh]',
      base_dir + 'Tests/Utils/**/*.[mh]',
    ]

    unit_tests.resources = base_dir + 'Tests/Fixture/**/*'
    unit_tests.dependency 'OCMock'
    unit_tests.requires_app_host = true
  end

  s.test_spec 'integration' do |integration_tests|
    integration_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    integration_tests.source_files = [
      base_dir + 'Tests/Integration/**/*.[mh]',
      base_dir + 'Tests/Integration/**/*.[mh]',
    ]
    integration_tests.resources = base_dir + 'Tests/Fixture/**/*'
    integration_tests.requires_app_host = true
  end

  s.test_spec 'swift-unit' do |swift_unit_tests|
    swift_unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    swift_unit_tests.source_files = [
      base_dir + 'Tests/Unit/Swift/**/*.swift',
      base_dir + 'Tests/Unit/Swift/**/*.h',
    ]
  end

end
