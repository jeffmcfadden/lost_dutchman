
class Sitemap
  attr_reader :host, :urls

  def initialize(host:)
    @host = host
  end

  def load
    @urls = File.open("sitemaps/#{host}.txt", 'r').read.split("\n").uniq rescue []
    self
  end

  def add_urls(new_urls)
    @urls = (@urls + new_urls).uniq
    self
  end

  def save
    File.open("sitemaps/#{host}.txt", 'w') { |file| file.write(urls.join("\n")) }
    self
  end

end