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
        create_file('Rakefile') unless File.exist?(File.join(destination_root, 'Rakefile'))
        prepend_to_file 'Rakefile', "require 'phobos_db_checkpoint'\nPhobosDBCheckpoint.load_tasks\n"
        copy_file 'templates/database.yml.example', 'config/database.yml'

        generated_migrations = list_migrations(File.join(destination_root, 'db/migrate'))
        template_migrations_metadata.each do |metadata|
          unless generated_migrations.find { |filename| filename =~ /#{metadata[:name]}/ }
            template "templates/migrate/#{metadata[:path]}", "db/migrate/#{metadata[:number]}_#{metadata[:name]}"
          else
            say_status 'exists', metadata[:name]
          end
        end
      end

      def self.source_root
        File.expand_path(File.join(File.dirname(__FILE__), '../..'))
      end

      private
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
    end
  end
end
