class Page
  attr_reader :id, :url, :links, :backlinks, :html_content, :content_type, :content_length, :last_modified, :etag, :last_crawl_code, :last_crawled_at
  attr_accessor :page_rank

  def initialize(url:, links: [], backlinks: [], page_rank: 0, content_type: nil, content_length: nil, last_modified: nil, etag: nil, last_crawl_code: nil, last_crawled_at: nil)
    @url = URI(url)
    @id = url_hash
    @links = []
    @backlinks = []
    @page_rank = page_rank
    @html_content = nil
    @content_type = content_type
    @content_length = content_length
    @last_modified = last_modified
    @etag = etag
    @last_crawl_code = last_crawl_code
    @last_crawled_at = last_crawled_at
  end

  def to_h
    {
      id: id,
      url: url.to_s,
      links: links.map(&:to_s),
      backlinks: backlinks.map(&:to_s),
      page_rank: page_rank,
      content_type: content_type,
      content_length: content_length,
      last_modified: last_modified,
      etag: etag,
      last_crawl_code: last_crawl_code,
      last_crawled_at: last_crawled_at
    }
  end

  def url_hash
    Digest::SHA256.hexdigest(self.url.to_s)
  end

  def load_html_content
    h = url_hash
    filename = "page_content/#{url.host}/#{h}"

    if File.exist?(filename)
      @html_content = File.read(filename)
    end
  end

  def extract_links
    return if @html_content.nil?

    doc = Nokogiri::HTML(@html_content)
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
  end

end