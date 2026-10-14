# Parses every JavaScript file in a folder with JSParser, prints it back,
# and checks the result with acorn (see compare.mjs): that the output is
# valid, means the same thing as the original, and is stable when parsed
# and printed again.
#
#   rake oracle DIR=path/to/js        (or rake "oracle[path/to/js]")
#
# Options (environment variables):
#   LIMIT=n     check at most n files
#   TIMEOUT=s   seconds allowed per file (default 5)
#   SHOW=n      failures to list per status (default 10)
#   MIN=1       include *.min.js files

require 'json'
require 'timeout'
require 'tmpdir'
require 'open3'
require 'jsparser'

module JSParser::Oracle
  DIR = File.expand_path(__dir__)
  STATUSES = %w(ok parse_error invalid_output mismatch unstable original_invalid)

  def self.run(folder)
    abort "Usage: rake oracle DIR=path/to/js" unless folder
    abort "No such folder: #{folder}" unless File.directory?(folder)
    ensure_acorn

    files = Dir.glob(File.join(File.expand_path(folder), "**", "*.{js,mjs,cjs}")).sort
    files.reject! { it.end_with?(".min.js") } unless ENV['MIN']
    files = files.first(Integer(ENV['LIMIT'])) if ENV['LIMIT']
    timeout = Float(ENV.fetch('TIMEOUT', 5))
    puts "Checking #{files.size} files in #{folder}"

    results = Dir.mktmpdir("jsparser-oracle") do |tmp|
      manifest = files.each_with_index.map do |file, i|
        print_progress(i, files.size)
        check(file, File.join(tmp, "#{i}#{File.extname(file)}"), timeout)
      end
      puts if $stdout.tty?

      path = File.join(tmp, "manifest.json")
      File.write(path, JSON.generate(manifest))
      out, err, status = Open3.capture3("node", File.join(DIR, "compare.mjs"), path)
      abort "compare.mjs failed:\n#{err}" unless status.success?
      JSON.parse(out)
    end

    report(results)
    exit 1 if results.any? { !%w(ok original_invalid).include?(it["status"]) }
  end

  # Parses and prints file, writing the output to output_path
  def self.check(file, output_path, timeout)
    source = File.read(file)
    output = Timeout.timeout(timeout) { JSParser.parse(source).to_js }
    File.write(output_path, output)
    again = Timeout.timeout(timeout) { JSParser.parse(output).to_js } rescue nil
    { source: file, output: output_path, stable: again == output }
  rescue Exception => e
    raise if e.is_a?(Interrupt)
    { source: file, error: "#{e.class}: #{e.message.lines.first(3).join.strip}" }
  end

  def self.report(results)
    by_status = results.group_by { it["status"] }
    show = Integer(ENV.fetch('SHOW', 10))

    (STATUSES - %w(ok)).each do |status|
      next unless (failures = by_status[status])
      puts "\n#{status} (#{failures.size})"
      failures.first(show).each do |r|
        puts "  #{r['source']}"
        puts r["detail"].to_s.lines.map { "      #{it}" }.join.rstrip
      end
      puts "  ... #{failures.size - show} more" if failures.size > show
    end

    checked = results.size - by_status.fetch("original_invalid", []).size
    puts "\n#{by_status.fetch('ok', []).size}/#{checked} ok" +
      (by_status["original_invalid"] ? " (#{by_status['original_invalid'].size} skipped, acorn can't parse the original)" : "")
  end

  def self.print_progress(i, total)
    return unless $stdout.tty?
    print "\r  parsed #{i + 1}/#{total}" if (i % 25).zero? || i + 1 == total
  end

  def self.ensure_acorn
    return if File.directory?(File.join(DIR, "node_modules", "acorn"))
    abort "node is required" unless system("node", "--version", out: File::NULL)
    puts "Installing acorn (npm install in #{DIR})"
    system("npm", "install", "--silent", chdir: DIR) or abort "npm install failed"
  end
end
