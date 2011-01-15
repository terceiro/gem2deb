class Gem2DebTestCase
  module Samples
    SAMPLE_DIR            = File.join(File.dirname(__FILE__), '..', 'sample')
    TMP_DIR               = Dir.mktmpdir

    SIMPLE_GEM            = File.join(SAMPLE_DIR, 'simplegem/pkg/simplegem-0.0.1.gem')
    SIMPLE_GEM_TARBALL    = File.join(TMP_DIR,    'simplegem-0.0.1.tar.gz')
  end
end
