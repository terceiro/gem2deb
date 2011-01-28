class Gem2DebTestCase
  module Samples
    SAMPLE_DIR            = File.join(File.dirname(__FILE__), '..', 'sample')
    TMP_DIR               = Dir.mktmpdir(['gem2deb.', '.tmp'])

    SIMPLE_GEM_NAME       = 'simplegem'
    SIMPLE_GEM_DIRNAME    = SIMPLE_GEM_NAME + '-0.0.1'
    SIMPLE_GEM            = File.join(SAMPLE_DIR, "#{SIMPLE_GEM_NAME}/pkg/#{SIMPLE_GEM_DIRNAME}.gem")

    SIMPLE_PROGRAM_NAME     = 'simpleprogram'
    SIMPLE_PROGRAM_DIRNAME  = SIMPLE_PROGRAM_NAME + '-1.2.3'
    SIMPLE_PROGRAM          = File.join(SAMPLE_DIR, "#{SIMPLE_PROGRAM_NAME}/pkg/#{SIMPLE_PROGRAM_DIRNAME}.gem")

    SIMPLE_EXTENSION_NAME     = 'simpleextension'
    SIMPLE_EXTENSION_DIRNAME  = SIMPLE_EXTENSION_NAME + '-1.2.3'
    SIMPLE_EXTENSION          = File.join(SAMPLE_DIR, "#{SIMPLE_EXTENSION_NAME}/pkg/#{SIMPLE_EXTENSION_DIRNAME}.gem")

    SIMPLE_TGZ_NAME       = 'simpletgz'
    SIMPLE_TGZ_DIRNAME    = SIMPLE_TGZ_NAME + '-0.0.1'
    SIMPLE_TGZ            = File.join(SAMPLE_DIR, "#{SIMPLE_TGZ_NAME}/pkg/#{SIMPLE_TGZ_DIRNAME}.tgz")
  end
end
