class Gem2DebTestCase
  module Samples
    SAMPLE_DIR            = File.join(File.dirname(__FILE__), '..', 'sample')
    TMP_DIR               = Dir.mktmpdir

    SIMPLE_GEM_DIRNAME    = 'simplegem-0.0.1'
    SIMPLE_GEM            = File.join(SAMPLE_DIR, "simplegem/pkg/#{SIMPLE_GEM_DIRNAME}.gem")
  end
end
