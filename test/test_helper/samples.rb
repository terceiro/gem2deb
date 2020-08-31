class Gem2DebTestCase
  module Samples
    SAMPLE_DIR            = File.join(File.dirname(__FILE__), '..', 'sample')
    TMP_DIR               = Dir.mktmpdir(['gem2deb.', '.tmp'])

    SIMPLE_GEM_NAME       = 'simplegem'
    SIMPLE_GEM_DIRNAME    = SIMPLE_GEM_NAME + '-0.0.1'
    SIMPLE_GEM            = File.join(SAMPLE_DIR, "#{SIMPLE_GEM_NAME}/pkg/#{SIMPLE_GEM_DIRNAME}.gem")
    SIMPLE_GEM_SOURCE     = File.join(SAMPLE_DIR, SIMPLE_GEM_NAME)

    SIMPLE_PROGRAM_NAME     = 'simpleprogram'
    SIMPLE_PROGRAM_DIRNAME  = SIMPLE_PROGRAM_NAME + '-1.2.3'
    SIMPLE_PROGRAM          = File.join(SAMPLE_DIR, "#{SIMPLE_PROGRAM_NAME}/pkg/#{SIMPLE_PROGRAM_DIRNAME}.gem")
    SIMPLE_PROGRAM_SOURCE   = File.join(SAMPLE_DIR, SIMPLE_PROGRAM_NAME)

    SIMPLE_EXTENSION_NAME     = 'simpleextension'
    SIMPLE_EXTENSION_DIRNAME  = SIMPLE_EXTENSION_NAME + '-1.2.3'
    SIMPLE_EXTENSION          = File.join(SAMPLE_DIR, "#{SIMPLE_EXTENSION_NAME}/pkg/#{SIMPLE_EXTENSION_DIRNAME}.gem")

    SIMPLE_ROOT_EXTENSION_NAME    = 'simpleextension_in_root'
    SIMPLE_ROOT_EXTENSION_DIRNAME = SIMPLE_ROOT_EXTENSION_NAME.gsub('_', '-') + '-1.2.3'
    SIMPLE_ROOT_EXTENSION         = File.join(SAMPLE_DIR, SIMPLE_ROOT_EXTENSION_NAME, 'pkg', "#{SIMPLE_ROOT_EXTENSION_NAME}-1.2.3.gem")

    SIMPLE_TGZ_NAME       = 'simpletgz'
    SIMPLE_TGZ_DIRNAME    = SIMPLE_TGZ_NAME + '-0.0.1'
    SIMPLE_TGZ            = File.join(SAMPLE_DIR, "#{SIMPLE_TGZ_NAME}/pkg/#{SIMPLE_TGZ_DIRNAME}.tgz")

    SIMPLE_MIXED_NAME     = 'simplemixed'
    SIMPLE_MIXED_DIRNAME  = SIMPLE_MIXED_NAME + '-1.2.3'
    SIMPLE_MIXED          = File.join(SAMPLE_DIR, "#{SIMPLE_MIXED_NAME}/pkg/#{SIMPLE_MIXED_DIRNAME}.gem")

    SIMPLE_GIT            = File.join(SAMPLE_DIR, 'simplegit')

    FANCY_PACKAGE_NAME      = 'Fancy_Package'
    FANCY_PACKAGE           = File.join(SAMPLE_DIR, "#{FANCY_PACKAGE_NAME}/pkg/#{FANCY_PACKAGE_NAME}-0.0.1.gem")

    KILLERAPP_DIR           = File.join(SAMPLE_DIR, 'killerapp')

  end
end
