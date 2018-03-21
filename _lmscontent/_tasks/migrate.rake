# -*- coding: utf-8 -*- #specify UTF-8 (unicode) characters
require 'learndot'
require 'learndot/learning_components'
require 'yaml'
require 'json'
require 'kramdown'
require 'upmark'
require 'diffy'
require 'html_validation'
require 'paint'

# This task is sort of a general purpose task for dealing with downloading
# content that was created prior to this workflow. It can be used to modify the
# json en masse.
# TODO: Ideally we should download content from production and compare the
# diffs of the html already present vs the html -> md -> html content that was
# generated by this task. 

  
namespace :migrate do

  # Connect to the learndot api
  def connect(target)
    # https://github.com/puppetlabs/learndot_api/blob/e1df5b0e1c64b09e7e48c504e98e2f3645f2eaf9/lib/learndot.rb#L22
    staging = target == 'production'  ? false : true

    # Configure the token for the target
    ENV['LEARNDOT_TOKEN'] = @config['credentials']['learndot'][target]['token']

    @lms = @lms || Learndot.new(true, staging).learning_component
  end

	# Show learning components
  def retrieve_all()
    @lms.retrieve_component({}).to_h
  rescue => e
    puts "#{e.message}"
    {}
  end

  # Show learning components
  def retrieve(name)
    @lms.retrieve_component({
      'name' => [ name.to_s ]
    }).to_h
  rescue => e
    puts "#{e.message}"
    {}
  end

  def normalize_name(name)
    name.lstrip.downcase.gsub(/(:|"|\.| |&|-)/,'_').squeeze('_')
  end

  def convert_utf8(string)
    string.gsub(/[”“‘’]/,
      '”' => '"',
      '“' => '"',
      '‘' => '\'',
      '’' => '\''
    )
  end

  # Attempt to convert the existing html content into markdown.
  # Most content is very simple and thus should work. This method attempts
  # to use one of two gems to do this convertion and in the event of failure
  # simply leaves the html in the file. This should be fine over time as
  # kramdown (md -> html gem) will ignore this html.

  def convert_fields_to_md(fields,lc,path)
    fields.each do |field|
      unless lc[field].nil?
        begin
          md = Upmark.convert(lc[field])
        rescue
          begin
            md = ReverseMarkdown.convert(lc[field])
          rescue
            md = lc[field]
          end
        end
        File.write("#{path}/#{field}.md",md)
      end
   end
  end

  # The structure of the names in the existing content are semi-formatted
  # For older content it was not built to be reusable. This meant it could be
  # grouped into sub folders and had a parent child relationship. This code
  # attempts to identify that relationship by parsing the name and splitting the
  # parent and child by the "-" in the name.
  def parse_and_build_structure(lc)
    # .gsub(/\w-/,' -') is to fix word- instead of word -
     match = lc['name'].gsub(/\w-/,' -').match(
       /(?<number>^[0-9]+\.(\s|\w))?(?<parent>.*(\s-\s|:))?(?<name>.*$)/
     )
     if match['parent']
       parent_dir = normalize_name(match['parent'].gsub(/ - /,''))
       child_dir  =  normalize_name("#{match['number']}#{match['name']}")
       path = "#{parent_dir}/#{child_dir}"
     else
       path = normalize_name(match['name'])
     end
     puts path
     FileUtils.mkdir_p path

     convert_fields_to_md(['content','description','summary'],lc,path)

     File.write("#{path}/metadata.json",lc.delete_if { |k,v| ['content', 'description', 'summary'].include? k }.to_json)
  end

  task :json do
    Dir.glob('**/*metadata.json').each do |path|
      puts path
      json = JSON.parse(File.read(path))
      if json['createdById'].nil?
        # If this field is missing, rewrite to be micheal
        json['createdById'] = 38
      end
      if json['price'].class == Hash
        json['price'] = "#{json['price']['amount']} #{json['price']['currency']}"
      end
      if json['duration'].class == Hash
        ['minutesPerDay','days'].each do |k|
          json["duration.#{k}"] = json['duration'][k]
        end
      end
      json.delete('duration')

      # The ids in staging don't seem to be permanent
      json.delete('id')

      # Delete the UUID, so you can copy and paste a learning comp
      json.delete('UUID')

      File.write(path,JSON.pretty_generate(json.delete_if { |k,v| ['components'].include? k }))

      if json.has_key?('components')
        json['components'].each do |lc|
          if lc['name']
            puts "Found nested component: #{lc['name']}"
            Dir.chdir(File.dirname(path)) do
              #parse_and_build_structure(lc)
            end
          end
        end
      end
    end
  end

  desc 'Fix issues with markdown'
  task :markdown do
    Dir.glob('**/*.md').each do |path|
      text = File.read(path)
      text = convert_utf8(text)
      File.write(path,text)
    end
  end

  # Rake Tasks
  task :components do
    # Connect to production or staging
    @lms = connect('staging')

    nested_lcs = {}
    retrieve_all.each do |page,lc|
      parse_and_build_structure(lc)
    end

  end

  desc 'Simulate a production deployment'
  task :production do
      # Update the reposositories from github
      #Rake::Task['download:repos'].invoke
      # Once repo is up to date , pull new commits from today
      git_dir = "./repos/courseware-lms-content"

      # Walk repo to find commits by date
      repo   = Rugged::Repository.new(git_dir)
      # Push version tags to production
      # Find the latest git tag by date & time
      tags = repo.references.each("refs/tags/v*").sort_by{|r| r.target.epoch_time}.reverse!

      raise "Can't deploy to production No matching (v*) tags found on this repository!" if tags[0].nil?

      # Use the last commit in the repo if only one tag exists
      parent = tags[1].nil? ? repo.last_commit : tags[1].target

      # Compare that tag to the tag that historically preceded it
      parent.diff(tags[0].target).each_delta do |delta|
      # Join the path with path repo and read the file into Kramdown
      # TODO: break this out to avoid duplication above
      next unless delta.new_file[:path] =~ %r{.*\.md$}
      next unless delta.new_file[:path] =~ %r{_lmscontent/.*$}
      next if     delta.new_file[:path] =~ %r{.*README.md$}

      component_directory = Pathname.new(delta.new_file[:path]).parent.basename
      puts "Found updated component #{component_directory} at path #{delta.new_file[:path]}"

      # Allow for subfolders
      if delta.new_file[:path].split('/').length == 4
        puts "Learning component in subfolder"
        parent_component_directory = Pathname.new(delta.new_file[:path]).parent.parent.basename
        rake_task_name = "#{parent_component_directory}-#{component_directory}"
      else
        rake_task_name = File.basename(component_directory)
      end
      
      puts "Processing: #{component_directory}"
      path = [parent_component_directory,component_directory,'metadata.json'].join('/')

      puts "Loading json #{path}"

      # Make a realtive path
      if path[0] == '/'
        path[0] = ''
      end

      json = JSON.parse(File.read(path))

      @lms = connect('production')
      retrieve(json['name']).each  do |id,component|
        puts Paint["Component: #{id} #{component['name']}", :blue, :bright, :underline]
        if component.empty?
          puts Paint["Component: #{component_directory} is missing from production",:red]
          next
        end
        Diffy::Diff.default_format = :color
        ['content','description','summary'].each do |field|
          puts Paint["Field: #{field}", :blue,:underline]
          field_path = [parent_component_directory,component_directory,"#{field}.md"].join('/')
          if File.exist?(field_path)
            doc = Kramdown::Document.new(File.read(field_path))
            html_validation = PageValidations::HTMLValidation.new
            html = html_validation.validation(doc.to_html, field)

            puts Diffy::Diff.new(component[field],doc.to_html)
            unless html.valid?
              puts Paint["HTML validation:", :blue, :underline]
              puts Paint[html.exceptions,"orange"]
            end
          end
        end
      end
    end
  end
end

