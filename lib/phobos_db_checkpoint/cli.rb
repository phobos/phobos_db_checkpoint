require 'thor'
require 'fileutils'

module PhobosDBCheckpoint
  module CLI

    class Commands < Thor
      include Thor::Actions

      map '-v' => :version
      map '--version' => :version

      desc 'version', 'Outputs the version number. Can be used with: phobos_db_checkpoint -v or phobos_db_checkpoint --version'
      def version
        puts PhobosDBCheckpoint::VERSION
      end

      desc 'init', 'Initialize your project with PhobosDBCheckpoint'
      def init
        create_file('Rakefile') unless File.exist?(File.join(destination_root, 'Rakefile'))
        prepend_to_file 'Rakefile', "require 'phobos_db_checkpoint'\nPhobosDBCheckpoint.load_tasks\n"
        copy_file 'templates/database.yml.example', 'config/database.yml'

        cmd = self.class.new
        cmd.destination_root = destination_root
        cmd.invoke(:copy_migrations)

        create_file('phobos_boot.rb') unless File.exist?(File.join(destination_root, 'phobos_boot.rb'))
        append_to_file 'phobos_boot.rb', File.read(phobos_boot_template)
      end

      desc 'copy-migrations', 'Copy required migrations to the project'
      option :destination,
             aliases: ['-d'],
             default: 'db/migrate',
             banner: 'Destination folder relative to your project'
      def copy_migrations
        destination_fullpath = File.join(destination_root, options[:destination])
        generated_migrations = list_migrations(destination_fullpath)
        FileUtils.mkdir_p(destination_fullpath)
        file_path = nil
        template_migrations_metadata.each do |metadata|
          if migration_exists?(generated_migrations, metadata[:name])
            say_status('exists', metadata[:name])
          else
            file_path = File.join(options[:destination], "#{metadata[:number]}_#{metadata[:name]}")
            template_path = File.join('templates/migrate', metadata[:path])
            template(template_path, file_path)
          end
        end
      rescue
        File.size(file_path) == 0 && FileUtils.rm(file_path)
        raise
      end

      desc 'migration NAME', 'Generates a new migration with the given name. Use underlines (_) as a separator, ex: add_new_column'
      option :destination,
             aliases: ['-d'],
             default: 'db/migrate',
             banner: 'Destination folder relative to your project'
      def migration(name)
        migration_name = name.gsub(/[^\w]*/, '')
        @new_migration_class_name = migration_name.split('_').map(&:capitalize).join('')
        file_name = "#{migration_number}_#{migration_name}.rb"
        destination_fullpath = File.join(destination_root, options[:destination], file_name)
        template(new_migration_template, destination_fullpath)
      end

      desc 'init-events-api', 'Initialize your project with events API'
      def init_events_api
        copy_file 'templates/config.ru', 'config.ru'
        say '   Start the API with: `rackup config.ru`'
      end

      def self.source_root
        File.expand_path(File.join(File.dirname(__FILE__), '../..'))
      end

      private

      def migration_exists?(list, name)
        list.find { |filename| filename =~ /#{name}/ }
      end

      def migration_number(index = 0)
        [Time.now.utc.strftime('%Y%m%d%H%M%S%6N'), '%.21d' % index].max
      end

      def template_migrations_metadata
        @template_migrations_metadata ||= begin
          index = 0
          template_migrations.map do |path|
            name = path.split('/').last
            index += 1
            {path: path, name: path.gsub(/\.erb$/, ''), number: migration_number(index)}
          end
        end
      end

      def template_migrations
        @template_migrations ||= list_migrations(migrations_template_dir)
      end

      def list_migrations(dir)
        return [] unless Dir.exist?(dir)
        Dir.entries(dir).select {|f| f =~ /\.rb(\.erb)?$/}
      end

      def migrations_template_dir
        File.join(self.class.source_root, 'templates/migrate')
      end

      def phobos_boot_template
        File.join(self.class.source_root, 'templates/phobos_boot.rb')
      end

      def new_migration_template
        File.join(self.class.source_root, 'templates/new_migration.rb.erb')
      end
    end
  end
end
