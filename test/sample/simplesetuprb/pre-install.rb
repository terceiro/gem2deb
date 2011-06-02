require 'fileutils'
FileUtils::mkdir_p("lib/simplesetuprb")

File.open("lib/simplesetuprb/generated.rb", "w") do |f|
    f.puts <<"EOF"

module SimpleSetuprb

  def self.generated_function
    return :generated
  end
end
EOF
end
