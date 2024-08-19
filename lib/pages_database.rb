class PagesDatabase
  attr_reader :pages

  # Allow usage via PagesDatabase.main
  # Definitely not thread safe here
  def self.main
    @main ||= PagesDatabase.new
  end

  def initialize
    @pages = {}
    load
  end

  # Example meta file: {"url":"http://1linereview2.blogspot.com/2009/06/mike-grost.html","content_type":"text/html","content_length":0,"last_modified":null,"etag":null,"code":200}
  def import_page_meta
    LOGGER.info "Starting: Importing page meta files"
    imported_files = []

    Dir.glob("page_meta/**/*").each do |filename|
      next if File.directory?(filename)
      begin
        data = JSON.load_file(filename)
        page = Page.new(url: data["url"], content_type: data["content_type"], content_length: data["content_length"], last_modified: data["last_modified"], etag: data["etag"], last_crawl_code: data["code"])
        add_page page
        imported_files << filename
      rescue StandardError => e
        LOGGER.error "Error importing #{filename}: #{e}"
      end
    end
    LOGGER.info "Finished: Importing page meta files."
    LOGGER.info "Pages database size: #{pages.size}"

    LOGGER.info "Starting: Saving pages database and cleaning up"
    save

    # Now, it should be safe to purge these files.
    imported_files.each do |filename|
      # FileUtils.rm(filename)
    end
    LOGGER.info "Finished: Saving pages database and cleaning up"

    self
  end

  def get_page(id)
    @pages[id]
  end

  def add_page(page)
    @pages[page.id] = page
  end

  def get_page_by_url(url)
    get_page id_for_url(url)
  end

  def id_for_url(url)
    Digest::SHA256.hexdigest url
  end

  private

  def load
    @pages = JSON.parse(File.open("pages.db").read).map{ |p| Page.new **p }.to_h{ |p| [p.id, p] }
  rescue
    @pages = {}
  end

  def save
    File.open("pages.db", "w") do |f|
      f.write(@pages.values.map(&:to_h).to_json)
    end
  end

end