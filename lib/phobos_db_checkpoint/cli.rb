require 'thor'

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
        insert_into_file 'Rakefile', "\nrequire 'phobos_db_checkpoint'\nPhobosDBCheckpoint.load_tasks", after: %r{require\s+["']bundler/gem_tasks["']}
        copy_file 'templates/database.yml.example', 'config/database.yml'
        each_migrations_with_number do |name, number|
          copy_file "templates/migrate/#{name}", "db/migrate/#{number}_#{name}"
        end
      end

      def self.source_root
        File.expand_path(File.join(File.dirname(__FILE__), '../..'))
      end

      def self.migrations_template_dir
        File.join(source_root, 'templates/migrate')
      end

      private

      def each_migrations_with_number
        migrations_dir = self.class.migrations_template_dir
        original_paths = Dir.entries(migrations_dir).select {|f| f =~ /\.rb$/}
        original_paths.each_with_index do |path, index|
          number = [Time.now.utc.strftime('%Y%m%d%H%M%S%6N'), '%.21d' % index].max
          name = path.split('/').last
          yield(path, number)
        end
      end

    end
  end
end
