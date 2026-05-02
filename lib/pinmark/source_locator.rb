# frozen_string_literal: true

module Pinmark
  module SourceLocator
    module_function

    def for(klass)
      return nil unless klass.name

      file, line = Module.const_source_location(klass.name)
      return nil unless file

      relative = Pathname.new(file).relative_path_from(Rails.root)
      "#{relative}:#{line}"
    end
  end
end
