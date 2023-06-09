class XMLCleaner

  # To ensure we make progress, we'll attempt to fix up to this many errors
  # before giving up.
  MAX_ITERATIONS = 10000

  def initialize
    @log = Rails.logger
  end

  def clean(file_path)
    factory = javax.xml.parsers.DocumentBuilderFactory.new_instance
    factory.setValidating(true)
    factory.setNamespaceAware(true)

    builder = factory.new_document_builder
    builder.setErrorHandler(NamespaceCorrectingErrorHandler.new(file_path))

    attempt = 0
    begin
      attempt += 1
      replace_html_entities(file_path)
      builder.parse(java.io.File.new(file_path))
    rescue NamespaceCorrectingErrorHandler::RetryParse
      if attempt >= MAX_ITERATIONS
        raise "Maximum error count (#{attempt}) exceeded for this document.  Giving up!"
      else
        @log.info("Corrected error in XML markup.  Parsing again (attempt: #{attempt}).")
        retry
      end
    rescue
      raise "Failed to clean XML: #{$!}"
    end
  end

  # Decode HTML entities so they can be parsed as XML
  def replace_html_entities(file_path)
    File.open(file_path + ".tmp", "w") do |outfile|
      File.open(file_path) do |infile|
        infile.each_with_index do |line, index|
          # The decode() method used below turns the five predefined XML entities into unescaped characters. That can
          # create non-well-formed XHTML, which will break PDF generation, so first replace them with something that
          # can be converted back safely afterwards.
          line.gsub!(/&(amp|lt|gt|quot|apos);/, '~~\1~~')
          line = HTMLEntities.new.decode(line)
          line.gsub!(/~~(amp|lt|gt|quot|apos)~~/, '&\1;')
          outfile.puts(line)
        end
      end
    end
    File.rename(file_path + ".tmp", file_path)
  end

  # An error handler that rewrites the underlying XML to resolve missing
  # namespace errors.
  class NamespaceCorrectingErrorHandler

    # Thrown to signal we can try parsing again
    class RetryParse < StandardError; end

    def initialize(file_path)
      @file_path = file_path
    end

    def fatal_error(exception)
      if exception.getMessage =~ /The prefix "(.*)" for .*? "(\1:.*?)".* is not bound./ &&
         exception.line_number &&
         exception.column_number

        # Caused by an undefined namespace such as `ns2:href`.  We can correct these
        element_to_fix = $2
        remove_namespace_prefix!(element_to_fix, exception.line_number, exception.column_number)

        raise RetryParse.new
      else
        raise exception
      end
    end

    def method_missing(*)
      # All other errors are ignored
    end

    private

    def remove_namespace_prefix!(element_to_fix, lineno, colno)
      File.open(@file_path + ".tmp", "w") do |outfile|
        File.open(@file_path) do |infile|
          infile.each_with_index do |line, index|
            if index == (lineno - 1)
              line = fix_line(line, element_to_fix, colno)
            end

            outfile.puts(line)
          end
        end
      end

      File.rename(@file_path + ".tmp", @file_path)
    end

    def fix_line(line, element_to_fix, colno)
      # Annoyingly, `collno` seems to point past the place that the error
      # actually happened, so we can't pinpoint the exact position to fix.
      # We'll just hope that valid text doesn't actually look like a namespace

      prefix, rest = element_to_fix.scan(/\A(.*?):(.*)\z/)[0]

      if prefix && rest
        line.gsub(element_to_fix, rest)
      else
        raise "Unexpected error while cleaning XML document: expected to find '#{element_to_fix}' in line #{line} but could not"
      end
    end
  end

end
