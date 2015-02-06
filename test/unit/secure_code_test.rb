require_relative '../test_helper'

class SecureCodeTest < Gem2DebTestCase

  should 'not interpolate variables into shell commands' do
    insecure_code = `grep -rl '\\(system\\|run\\)[( ][^,]*\#{' lib/ bin/`.split
    unless insecure_code.empty?
      fail "files containing insecure code: \n\t" + insecure_code.join("\n\t")
    end
  end unless ENV['ADTTMP']

end
