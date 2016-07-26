require 'csv'
require 'yaml'
require 'rchardet'

module LeesToolbox

  def self.run(params)
    md = Markdown.new(params)
    md.translate
  end

  class Markdown
    HTML_FILTER = YAML.load(File.open("lib/lees_toolbox/tools/markdown/htmlmap.yml"))

    def initialize(params)
      @type = params[:type]
      @descriptions = get_descriptions(params[:source])
      path = File.dirname(params[:source])
      filename = File.basename(params[:source],@type)
      @target = File.open("#{path}/#{filename}-FILTERED#{@type}", "w")
    end

    def translate
      if @type == ".txt"
        format!(@descriptions)
      else
        output = "descriptions\n"
        @descriptions.each do |description|
          output << format!(description).gsub(/[\n\"]/, "\n"=>'\n', '"'=>'\"')
          output << "\n"
        end
#binding.pry
      end
      @descriptions = output
      write_to_file
    end

    private
  
    # METHOD: write_to_file
    # write formatted descriptions back to file
    def write_to_file
      @target << @descriptions
      if !@target.closed?
        @target.close
      end
    end

    # METHOD: get_descriptions(file)
    # Opens csv file and converts to proper format
    # Returns array of descriptions for translation
    def get_descriptions(file)
      # Convert to UTF-8
      enc = CharDet.detect(File.read(file))["encoding"]

      # Header_converter proc
      nospaces = Proc.new{ |head| head.gsub(" ","_") }

      if @type == ".txt"
        if enc["encoding"].downcase != "utf-8"
          encoder = Encoding::Converter.new(enc, "UTF-8", :universal_newline=>true)
          descriptions = encoder.convert(File.read(file))
        else
          descriptions = File.read(file)
        end
      else
        csv_data = CSV.read(file, :headers => true, :header_converters => [:downcase, nospaces], :skip_blanks => true, :encoding => "#{enc}:UTF-8")
        # Get just the descriptions column
        # If :desc is present, that's it
        headers = csv_data.headers
        if headers.include?("desc")
          descriptions = csv_data["desc"]
        else
          # Otherwise, ask which column to use
          header = ""
          while !headers.include?(header)
            puts "Which column has product descriptions?"
            headers.each { |h| puts "\t#{h}" }
            print "#: "
            header = gets.chomp
            descriptions = csv_data[header]
          end
        end
      end
      descriptions
    end

    # METHOD: format!(text)
    def format!(text)
      output = "<ECI>"
      # Divide into hash of sections
      sections = sectionize(text)
      # Format each section
      sections.each do |section|
        output << filter(section)
      end
      output
    end

    # METHOD: sectionize(text)
    # Divide MD-formatted text into hash of component sections
    def sectionize(text)
      sections = {}
      splits = text.split("{")
      splits.delete_at(0)
#binding.pry
      splits.each do |splitted|
        part = splitted.split("}")
        sections[part[0]] = part[1].strip
      end
      sections
    end

    # METHOD: filter(section)
    # Use markdown rules to format section of text
    def filter(section)
      # section should be a paired array
      section[0] = section[0].split("#")
      head = section[0][0]
      rule = section[0][1]

      if head == "product_name"
        body = title_text(section[1])
      else
        body = section[1]
      end
    
      body
    end

    # METHOD: title_text(text)
    # Format text in title case
    def title_text(text)
      # Words we don't cap
      no_cap = ["a","an","the","with","and","but","or","on","in","at","to"]
      # Strip out dumb characters
      title = strip_chars(text)
      # Cycle through words
      title = title.split
      title.map! do |word|
        # First word is Vendor name - don't mess with it
        if word != title[0]
          # If asterisked or starts with a period, leave it alone
          if word[0] == "*"
            thisword = word.sub!("*","")
          # If it is a number leave it alone
          elsif word[0] =~ /[\.\d]/
            thisword = word
          # If there's a dash and the word's longer than 1 char
          elsif word.include?('-') && word.length > 1
            # Split at - and cap both sides
            thisword = word.split('-').each{|i| i.capitalize!}.join('-')
          # If in no_cap list, don't cap it
          elsif no_cap.include?(word.downcase)
            thisword = word.downcase
          # Otherwise, cap it
          else
            thisword = word.downcase.capitalize
          end
        else
          thisword = word
        end
        thisword
      end
      title.join(' ')
    end

    # METHOD: strip_chars(text)
    # Removes dumb weird characters
    def strip_chars(text)
      text
    end

    # METHOD: clean_html(text)
    # Cleans up special characters in html
    def clean_html(text)

    end

=begin
# Converts the product description into a hash
# with the "product_name",
# "description", "features", and "specs"
def hashify(string)
  hash = Hash.new
  if string != nil
    string = string.split(/\n(?=\{)/)
    string.each do |section|
      hash[ ( section.slice(/[\w\d\_\#]+(?=\})/) ) ] = section[(section.index('}')+1)..-1].strip
    end
  end
  return hash
end

# encode special characters for HTML
def html_sanitizer(string, set=:basic)
  if set == :basic
    $htmlmap = MAPPINGS[:base]
  else
    $htmlmap = MAPPINGS[:base].merge!(MAPPINGS[:title])
  end

  string = string.split("")
  string.map! { |char|
    ( $htmlmap.has_key?(char.unpack('U')[0]) ) ? $htmlmap[char.unpack('U')[0]] : char
  }


  return string.join
end

# replace \r\n line endings with \n line endings
# check encoding, if not UTF-8, transcode
def file_sanitizer(file)
  file = File.open(file, mode="r+")
  content = File.read(file)
	content.force_encoding(Encoding::Windows_1252)
	content = content.encode!(Encoding::UTF_8, :universal_newline => true)
  content.gsub!("\r\n","\n")
  file.write(content)
end


# sanitize and capitalize
def product_name(string)
  string = html_sanitizer(title_case(string),:title)
end


# Make it a list
def listify(string)
  output = "<ul>\n"
  string.gsub!(/\:\n/, ":")
  arrayify = string.split("\n")
  arrayify.each do |line|
    line.strip!
    if line.length>0
      output << "\t<li>#{line}</li>\n"
    end
  end
  output << "</ul>\n"
end

# Make it segments
def segmentify(string)
  output = "<br>"
  array = string.split(/\n/)
  array.each do |x|
    if x.match(":")
      output << "#{x}<br>\n"
    else
      output << "<strong>#{x}</strong><br>\n"
    end
  end
  return output
end

# Make it a table
def tablify(string)
  output = "<table>\n"
  r = 0
  array = string.split(/\n/)
  array.each do |x|
    if !x.nil?
      output << "\t<tr>\n"
      x.gsub!("  ","\t")
      row = x.split(/\t/)
      row.each do |y|
        if r>0
          output << "\t\t<td>#{y}</td>\n"
        else
          output << "\t\t<th>#{y}</th>\n"
        end
      end
      output << "\t</tr>\n"
      r += 1
    end
  end
  output << "</table>\n\n"
  return output
end

# makes it a paragraph
def grafify(string)
  string.strip!
  string.gsub!("\n","<br>")
end


def format_section(string,format)
  string=html_sanitizer(string)
  case format
  when "table"
    string = tablify(string)
  when "seg"
    string = segmentify(string)
  when "graf"
    string = grafify(string)
  when "list" # is default
    string=listify(string)
  else
    string=listify(string)
  end
  return string
end


def formatify(string)
  output = ""
  product_data = hashify(string)
  temp_data = Hash.new
  product_data.each do |k,v|
    format = "" # marks what format to put section into
    if k.match("#")
      split = k.split("#")
      k = split[0]
      format = split[1]
    end

    case k #checks key
    when "product_name"
      temp_data[k]=product_name(v)
    when "description"
      temp_data[k] = "<p id=\"description\">#{html_sanitizer(v)}</p>\n"
    when "features"
      temp_data[k] = "<p id=\"features\">\n<u>Features</u>\n#{format_section(v,format)}\n</p>\n"
    when "specs"
      temp_data[k] = "<p id=\"specifications\">\n<u>Specifications</u>\n#{format_section(v,format)}\n</p>\n"
    end
  end
  output << body_format(temp_data)
  return output
end


def body_format(hash)
  product_name = hash["product_name"]
  description = hash["description"]
  features = hash["features"]
  specs = hash["specs"]

  body_format = "<ECI>\n<font face='verdana'>\n"
  body_format << "<h2 id=\"product_name\">#{hash['product_name']}</h2>\n"
  if hash.has_key? 'description'
    body_format << hash['description']
  end
  if hash.has_key? 'features'
    body_format << hash['features']
  end
  if hash.has_key? 'specs'
    body_format << hash['specs']
  end

  body_format << "</font>"

end
=end


  end
end