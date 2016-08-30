![CircleCI](https://circleci.com/gh/klarna/phobos_db_checkpoint/tree/master.svg?style=shield&circle-token=a69fda09f130a862b69f6a7e8be834f884829ccd)
[![Coverage Status](https://coveralls.io/repos/github/klarna/phobos_db_checkpoint/badge.svg)](https://coveralls.io/github/klarna/phobos_db_checkpoint)

# Phobos DB Checkpoint

Phobos DB Checkpoint is a plugin to [Phobos](https://github.com/klarna/phobos) and is meant as a drop in replacement to `Phobos::Handler`, extending it with the following features:
 * Persists your Kafka events to an active record compatible database
 * Ensures that your [handler](https://github.com/klarna/phobos#usage-consuming-messages-from-kafka) will consume messages only once
 * Allows your system to quickly reprocess events in case of failures

## Table of Contents

1. [Installation](#installation)
1. [Usage](#usage)
  1. [Setup](#setup)
  1. [Handler](#handler)
  1. [Accessing the events](#accessing-the-events)
  1. [Instrumentation](#instrumentation)
1. [Development](#development)

## <a name="installation"></a> Installation

Add this line to your application's Gemfile:

```ruby
gem 'phobos_db_checkpoint'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install phobos_db_checkpoint

## <a name="usage"></a> Usage

The main idea of Phobos DB Checkpoint is to replace the default handler `Phobos::Handler` with `PhobosDBCheckpoint::Handler`.

In order to use it, you have to [setup the database](#setup) and [switch your handler](#handler) to use the `PhobosDBCheckpoint::Handler` instead.

### <a name="setup"></a> Setup

Phobos DB Checkpoint exposes a CLI to help you setup your project, assuming an [already configured phobos project](https://github.com/klarna/phobos#usage-standalone-apps). Example:

```sh
# run this command inside your app directory
$ phobos_db_checkpoint init
      create  Rakefile
     prepend  Rakefile
      create  config/database.yml
      create  db/migrate/20160825183351479299_phobos_01_create_events.rb
      append  phobos_boot.rb
```

The __init__ command will generate the base migrations, an example of `database.yml`, and add the default configuration into `phobos_boot.rb` and `Rakefile` for your convenience.

After this, your app should have access to all db tasks.

```sh
$ rake -T
    rake db:create              # Creates the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:create:all to create all ...
    rake db:drop                # Drops the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:drop:all to drop all databa...
    rake db:environment:set     # Set the environment value for the database
    rake db:fixtures:load       # Loads fixtures into the current environment's database
    rake db:migrate             # Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog)
    rake db:migrate:status      # Display status of migrations
    rake db:rollback            # Rolls the schema back to the previous version (specify steps w/ STEP=n)
    rake db:schema:cache:clear  # Clears a db/schema_cache.dump file
    rake db:schema:cache:dump   # Creates a db/schema_cache.dump file
    rake db:schema:dump         # Creates a db/schema.rb file that is portable against any DB supported by Active Record
    rake db:schema:load         # Loads a schema.rb file into the database
    rake db:seed                # Loads the seed data from db/seeds.rb
    rake db:setup               # Creates the database, loads the schema, and initializes with the seed data (use db:reset to also drop the database first)
    rake db:structure:dump      # Dumps the database structure to db/structure.sql
    rake db:structure:load      # Recreates the databases from the structure.sql file
    rake db:version             # Retrieves the current schema version number
```

##### Note

You can always re-generate the base migrations using the command __copy-migrations__, example:

```sh
$ phobos_db_checkpoint copy-migrations
      exists  phobos_01_create_events.rb
```

This command has no side effects, if the migration is already present it will ignore it.

### <a name="handler"></a> Handler

In order to use the database checkpointing, your handler should be changed to include `PhobosDBCheckpoint::Handler` instead of `Phobos::Handler`. Phobos DB Checkpoint handler uses the Phobos `around_consume` functionality, which means you need to implement a `#consume` method to handle the event.

Since Phobos DB Checkpoint will only save acknowledged events, you need to return from `#consume` with an invocation to `#ack` with the __entity_id__ and __event_time__ of your event. Example:

```ruby
class MyHandler
  include PhobosDBCheckpoint::Handler

  def consume(payload, metadata)
    my_event = JSON.parse(payload)
    # <-- your logic (which possibly skips messages) here
    ack(my_event['id'], Time.now)
  end
end
```

If your handler returns anything different than an __ack__ it won't be saved to the database.

Note that the `PhobosDBCheckpoint::Handler` will automatically skip already handled events (i.e. duplicate Kafka messages).

### <a name="accessing-the-events">Accessing the events</a>

`PhobosDBCheckpoint::Event` is a plain `ActiveRecord::Base` model, feel free to play with it.

### <a name="instrumentation"></a> Instrumentation

Some operations are instrumented using [Phobos::Instrumentation](https://github.com/klarna/phobos#usage-instrumentation)

#### Handler notifications

Overview of the built in notifications:
  * `db_checkpoint.event_acknowledged` is sent when the event is acknowledged (saved)
  * `db_checkpoint.event_skipped` is sent when the event is skipped (not saved)
  * `db_checkpoint.event_already_consumed` is sent when the handler receives an existing message (not saved)

The following payload is included for all notifications:
  * listener_id
  * group_id
  * topic
  * key
  * partition
  * offset
  * retry_count
  * checksum

## <a name="development"></a> Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rspec spec` to run the tests.

To install this gem in your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/klarna/phobos_db_checkpoint.

## License

Copyright 2016 Klarna

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.

You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
