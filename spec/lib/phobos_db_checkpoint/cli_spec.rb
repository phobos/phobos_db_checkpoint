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
  end

end
