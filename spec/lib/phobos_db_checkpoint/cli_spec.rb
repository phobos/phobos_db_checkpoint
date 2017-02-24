require 'spec_helper'
require 'fileutils'
require 'phobos_db_checkpoint/cli'

RSpec.describe PhobosDBCheckpoint::CLI do
  let(:root) { File.expand_path(File.join(File.dirname(__FILE__), '../../..')) }
  let(:destination_root) { File.join(root, 'spec/tmp') }

  before do
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)
  end

  after do
    FileUtils.rm_rf(destination_root)
  end

  describe '$ phobos_db_checkpoint init' do
    let(:invoke_cmd) do
      cmd = PhobosDBCheckpoint::CLI::Commands.new
      cmd.destination_root = destination_root
      cmd.invoke(:init)
    end

    it 'add require and load_tasks to Rakefile' do
      invoke_cmd
      expect(File.exists?('spec/tmp/Rakefile')).to eql true
      expect(File.read(File.join(destination_root, 'Rakefile')))
        .to eql <<~FILE
          require 'phobos_db_checkpoint'
          PhobosDBCheckpoint.load_tasks
        FILE
    end

    it 'copy database.yml.example to config/database.yml' do
      invoke_cmd
      expect(File.exists?('spec/tmp/config/database.yml')).to eql true
      expect(File.read(File.join(destination_root, 'config/database.yml')))
        .to eql File.read(File.join(root, 'templates/database.yml.example'))
    end

    it 'copy migrations to db/migrate' do
      invoke_cmd
      template_migrations = Dir
        .entries(File.join(root, 'templates/migrate'))
        .select {|f| f =~ /\.rb$/}

      generated_migrations = Dir
        .entries(File.join(destination_root, 'db/migrate'))
        .select {|f| f =~ /\.rb$/}

      template_migrations.each do |migration|
        expect(generated_migrations.find { |m| m =~ /\d+_#{migration}/ }).to_not be_nil
      end
    end

    it 'add db:migrate to phobos_boot.rb' do
      invoke_cmd
      expect(File.exists?('spec/tmp/phobos_boot.rb')).to eql true
      expect(File.read(File.join(destination_root, 'phobos_boot.rb')))
        .to eql File.read(File.join(root, 'templates/phobos_boot.rb'))
    end
  end

  describe '$ phobos_db_checkpoint version' do
    let(:invoke_cmd) do
      cmd = PhobosDBCheckpoint::CLI::Commands.new
      cmd.destination_root = destination_root
      cmd.invoke(:version)
    end

    it 'prints the version' do
      expect(STDOUT).to receive(:puts).with(PhobosDBCheckpoint::VERSION)
      invoke_cmd
    end
  end

  describe '$ phobos_db_checkpoint migration NAME' do
    let(:invoke_cmd) do
      cmd = PhobosDBCheckpoint::CLI::Commands.new
      cmd.destination_root = destination_root
      cmd.invoke(:migration, [migration_name])
    end

    let(:migration_name) { 'add_new_column-' }

    it 'creates a new migration with the given name' do
      invoke_cmd
      generated_migration = Dir
        .entries(File.join(destination_root, 'db/migrate'))
        .select {|f| f =~ /\.rb$/}
        .find {|f| f =~ /\d+_add_new_column.rb\Z/}

      expect(generated_migration).to_not be_nil
    end

    it 'creates a valid constant name with the given name' do
      invoke_cmd
      migration_name = Dir
        .entries(File.join(destination_root, 'db/migrate'))
        .find {|f| f =~ /\d+_add_new_column.rb\Z/}

      migration_path = File.join(destination_root, 'db/migrate', migration_name)
      expect(File.read(migration_path)).to match('class AddNewColumn < ActiveRecord::Migration')
    end
  end

  describe '$ phobos_db_checkpoint init-events-api' do
    let(:invoke_cmd) do
      cmd = PhobosDBCheckpoint::CLI::Commands.new
      cmd.destination_root = destination_root
      cmd.invoke(:init_events_api)
    end

    it 'copy config.ru to root' do
      invoke_cmd
      expect(File.exists?('spec/tmp/config.ru')).to eql true
      expect(File.read(File.join(destination_root, 'config.ru')))
        .to eql File.read(File.join(root, 'templates/config.ru'))
    end
  end
end
