![CircleCI](https://circleci.com/gh/klarna/phobos_db_checkpoint/tree/master.svg?style=shield&circle-token=a69fda09f130a862b69f6a7e8be834f884829ccd)
[![Coverage Status](https://coveralls.io/repos/github/klarna/phobos_db_checkpoint/badge.svg?branch=master)](https://coveralls.io/github/klarna/phobos_db_checkpoint?branch=master)

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
    1. [Failures](#failures)
  1. [Accessing the events](#accessing-the-events)
  1. [Events API](#events-api)
  1. [Instrumentation](#instrumentation)
1. [Upgrading](#upgrading)
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
    rake db:create              # Creates the database from DATABASE_URL or config/database.yml for the current RACK_ENV (use db:create:all to create all ...
    rake db:drop                # Drops the database from DATABASE_URL or config/database.yml for the current RACK_ENV (use db:drop:all to drop all databa...
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

You can generate new migrations using the command __migration__, example:

```sh
phobos_db_checkpoint migration add-new-column
      create  db/migrate/20160904200449879052_add_new_column.rb
```

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

#### <a name="failures"></a> Failures

If your handler fails during the process of consuming the event, the event will be processed again acknowledged or skipped. The default behavior of `Phobos` is to back off but keep retrying the same event forever, in order to guarantee messages are processed in the correct order. However, this blocking process could go on indefinitely, so in order to help you deal with this PhobosDBCheckpoint can (on an opt-in basis) mark them as permanently failed after a configurable number of attempts.

This configuration is set in Phobos configuration:

```yml
db_checkpoint:
  max_retries: 3
```

The retry decision is driven by inspecting the retry counter in the Phobos metadata, and if not meeting the retry criteria it will result in creating a `Failure` record and then skipping the event. You can easily retry these events later by simply invoking `retry!` on them.

Optionally, by overriding the `retry_consume?` method you can take control over the conditions that apply for retrying consumption. Whenever these are not met, a failing event will be moved out of the queue and become a Failure.

The control is based on `payload` and `exception`:

```ruby
class MyHandler
  include PhobosDBCheckpoint::Handler

  def self.retry_consume?(event, event_metadata, exception)
    event_metadata[:retry_count] <= MyApp.config.max_retries
  end
end
```

##### Failure details

Since PhobosDBCheckpoint does not know about the internals of your payload, for setting certain fields it is necessary to yield control back to the application.
In case you need to customize your failures, these are the methods you should implement in your handler:

```ruby
class MyHandler
  include PhobosDBCheckpoint::Handler
    def entity_id(payload)
      # Extract event id...
      payload['my_payload']['my_event_id']
    end

    def entity_time(payload)
      # Extract event time...
      payload['my_payload']['my_event_time']
    end

    def event_type(payload)
      # Extract event type...
      payload['my_payload']['my_event_type']
    end

    def event_version(payload)
      # Extract event version...
      payload['my_payload']['my_event_version']
    end
  end
end
```

This is completely optional, and if a method is not implemented, the corresponding value will simply be set to null.

### <a name="accessing-the-events">Accessing the events</a>

`PhobosDBCheckpoint::Event` is a plain `ActiveRecord::Base` model, feel free to play with it.

### <a name="events-api"></a> Events API

Phobos DB Checkpoint comes with a sinatra app which makes the event manipulation easy through its JSON API.

The __init_events_api__ command will generate a `config.ru` ready to use:

```sh
$ phobos_db_checkpoint init_events_api
   create  config.ru
   Start the API with: `rackup config.ru`
```

The available routes are:

* GET `/ping`
* GET `/v1/events/:id`
* GET `/v1/events` This route accepts the following params:
  * `limit`, default: 20
  * `offset`, default: 0
  * `entity_id`
  * `topic`
  * `group_id`
  * `event_type`
* POST `/v1/events/:id/retry`
* GET `/v1/failures/:id`
* DELETE `/v1/failures/:id`
* GET `/v1/failures` This route accepts the following params:
  * `limit`, default: 20
  * `offset`, default: 0
  * `entity_id`
  * `topic`
  * `group_id`
  * `event_type`
* POST `/v1/failures/:id/retry`

#### Events endpoint

Sample output for event:

```sh
$ curl "http://localhost:9292/v1/events/1"
# {
#   "id": 1,
#   "topic": "test-partitions",
#   "group_id": "test-checkpoint-1",
#   "entity_id": "1",
#   "event_time": "2016-09-19T19:35:26.854Z",
#   "event_type": "create",
#   "event_version": "v1",
#   "checksum": "188773471ec0f898fd81d272760a027f",
#   "payload": {
#     "a": "b"
#   }
# }
```

#### Failures endpoint

Sample output for failure:

```sh
$ curl "http://localhost:9292/v1/failures/1"
# {
#   "id": 1,
#   "created_at": "2017-02-28T07:53:21.790Z",
#   "topic": "test-partitions",
#   "group_id": "test-checkpoint-1",
#   "entity_id": "32de6e8e-4317-4ff7-bbce-aa4a6d41294a",
#   "event_time": "2016-08-10T07:07:58.907Z",
#   "event_type": "test-event-type",
#   "event_version": "v1",
#   "checksum": "12c9e42bca2728fc8193c87979bfe510",
#   "payload": {
#     "a": "b"
#   },
#   "metadata": {
#     "c": "d"
#   },
#   "error_class": "Faraday::ConnectionFailed",
#   "error_message": "Failed to open TCP connection to localhost:9200 (Connection refused - connect(2) for \"localhost\" port 9200)",
#   "error_backtrace": [
#     "/Users/mathias.klippinge/.rvm/rubies/ruby-2.3.3/lib/ruby/2.3.0/net/http.rb:882:in `rescue in block in connect'",
#     "/Users/mathias.klippinge/.rvm/rubies/ruby-2.3.3/lib/ruby/2.3.0/net/http.rb:879:in `block in connect'",
#     "..."
#   ]
# }
```

### <a name="instrumentation"></a> Instrumentation

Some operations are instrumented using [Phobos::Instrumentation](https://github.com/klarna/phobos#usage-instrumentation)

#### Handler notifications

Overview of the built in notifications:
  * `db_checkpoint.around_consume` is sent when the event has run all logic in `around_consume`, this encompasses many of the below instrumentations at a higher level
  * `db_checkpoint.event_already_exists_check` is sent when the event has been queried for existence in the database
  * `db_checkpoint.event_action` is sent when the event action has completed
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

## <a name="upgrading"></a> Upgrading

#### From 2.2.0 >= _version_ >= 2.0.0 to 2.3.0

The database table for Event has had created_at added to it, run `phobos_db_checkpoint copy-migrations` in your project to receive the migration.

#### From <2.0 to 2.x

##### Rename database tables

The database table names for Event and Failure has been changed to be namespaced under `phobos_db_checkpoint_` to avoid potential collisions with projects that already have these names.

This means that when upgrading one would have to add a new migration to rename from old name to new:

```ruby
def up
  rename_table :events, :phobos_db_checkpoint_events
  rename_table :failures, :phobos_db_checkpoint_failures
end
```

Alternatively, one could potentially configure the tables to use the old names, as such:

```ruby
PhobosDBCheckpoint::Event.table_name = :events
PhobosDBCheckpoint::Failure.table_name = :failures
```

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
