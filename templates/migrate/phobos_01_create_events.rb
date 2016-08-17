class Phobos01CreateEvents < ActiveRecord::Migration
  def up
    create_table :events do |t|
      t.string    :topic,         index: true
      t.string    :consumer,      index: true
      t.string    :entity_id,     index: true
      t.timestamp :event_time,    index: true
      t.string    :event_type,    index: true
      t.string    :event_version, index: true
      t.string    :checksum,      index: true
      t.json      :payload
    end

    add_index :events, [:topic, :consumer, :checksum]
  end

  def down
    drop_table :events
  end
end
