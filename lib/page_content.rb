class PageContent
  attr_reader :page, :host, :page, :html_content, :links, :title, :words

  # @param host [String]
  # @param page [Page]
  def initialize(host:, page:)
    @host = host
    @page = page
    @html_content = ""
    @links = []
    @title = []
    @words = {}
  end

  # @return [PageContent] self
  def load
    filename = "page_content/#{host}/#{page.id}"
    if File.exist?(filename)
      @html_content = File.open(filename).read
    end

    self
  end

  def analyze
    @title = nil
    @links = []

    doc = Nokogiri::HTML(@html_content)

    self.title = doc.css('title').text

    doc.css('a').each do |a|
      link = a['href']
      next if link.nil?

      begin
        uri = URI(link)
        uri = URI.join(url, uri) if uri.relative?
        @links << uri
      rescue URI::InvalidURIError
        LOGGER.error "Invalid URI: #{link}"
      end
    end

    self
  end

end