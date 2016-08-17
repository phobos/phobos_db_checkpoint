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

        template_migrations_metadata.each do |metadata|

          if migration_exists?(generated_migrations, metadata[:name])
            say_status('exists', metadata[:name])

          else
            file_path = File.join(options[:destination], "#{metadata[:number]}_#{metadata[:name]}")
            template_path = File.join('templates/migrate', metadata[:path])
            template(template_path, file_path)
          end

        end
      end

      def self.source_root
        File.expand_path(File.join(File.dirname(__FILE__), '../..'))
      end

      private
      def migration_exists?(list, name)
        list.find { |filename| filename =~ /#{name}/ }
      end

      def template_migrations_metadata
        @template_migrations_metadata ||= begin
          index = 0
          template_migrations.map do |path|
            number = [Time.now.utc.strftime('%Y%m%d%H%M%S%6N'), '%.21d' % index].max
            name = path.split('/').last
            index += 1
            {path: path, name: path.gsub(/\.erb$/, ''), number: number}
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
    end
  end
end
