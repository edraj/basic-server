require "json"
require "uuid"
require "uuid/json"
require "./exts"
require "./config"

module Edraj
  enum ResourceType
    # Non-entry types. Respective classes and json-schema exist
    Notification
    Invitation
    Reply
    Reaction
    Subscription
    Schema
    Token
    Locator
    Media
    Signature
    Relationship

    # Entry types. No classes, only json-schema
    Folder  # Folder "only"
    Contact # Person or Organization
    Profile
    Post
    Message
    Task
    Term
    Biography
    Location # Aka Address
    Page
    Block
    # Other
  end

  enum ScopeType
    Base
    Onelevel
    Subtree
  end

  class Locator
    include JSON::Serializable
    property type : ResourceType
    property uuid : UUID
    property space : String
    property subpath : String
    property uri : String
  end

  class Relationship
    include JSON::Serializable
    property type : String
    property properties = {} of String => JSON::Any
    property related_to : Locator
  end

  class Signature
    include JSON::Serializable
    property fields : Array(String)
    property timestamp : Time
    property checksum : String
    property keyid : String
    property actor : UUID
    property hash : String

    def verify : Bool
    end
  end

  class Base
    include JSON::Serializable
    property uuid : UUID
    property timestamp : Time
    property signature : Signature
    property author : UUID?
    property type : ResourceType
    property space : String
    property subpath : String

    # Save
    def save(filename : String)
      path = Edraj.settings.data_path / @space / @subpath
      Dir.mkdir_p path.to_s unless Dir.exists? path.to_s
      File.write path / filename, to_pretty_json
    end
  end

  class Entry < Base
    property shortname : String
    property displayname : String
    property description : String?
    property tags = Array(String).new
    property properties : Hash(String, AnyBasic)

    def locator : Locator
      Locator.from_json({
        type:    @type,
        uuid:    @uuid,
        space:   @space,
        subpath: @subpath,
      }.to_json)
    end

    # List files
    def self.list(path, glob = "*")
      list = [] of UUID
      Dir.glob("#{path}/#{glob}") do |one|
        list << UUID.random #FIXME 
      end
      list
    end

    # Delete
    def self.delete(path : Path, filename : String)
      File.delete path / filename
    end

    # Move
    def self.move(old : Path, new : Path)
      File.move old, new
    end

    def replies : Hash(UUID, Reply)
      Hash(UUID, Reply).new
    end

    def reactions : Hash(UUID, Reaction)
      Hash(UUID, Reaction).new
    end

    def media : Hash(UUID, Media)
      Hash(UUID, Media).new
    end

    def subentries : Hash(UUID, Entry)
      Hash(UUID, Entry).new
    end

    def relationships : Array(Relationship)
      Array(Relationship).new
    end
  end

  class Post < Entry
    property body : String
  end

  class Contributer < Base
    property about : String
  end

  class Task < Entry
  end

  class Subscription < Base
    property filter : String
  end

  enum ReactionType
    Like
    Love
    Dislike
    Laugh
    Angry
    Sad
  end

  class Reaction < Base
    property reaction_type : ReactionType
    property response_to_uuid : UUID
  end

  class Reply < Base
    property body : String
    property response_to_uuid : UUID?

    def replies : Hash(UUID, Reply)
      Hash(UUID, Reply).new
    end

    def reactions : Hash(UUID, Reaction)
      Hash(UUID, Reaction).new
    end

    def media : Hash(UUID, Media)
      Hash(UUID, Media).new
    end
  end

  #  class Message < Base
  #    property subject : String?
  #		property body : String
  #    property from : UUID
  #    property to : Array(UUID)
  #    property thread_id : UUID
  #  end

  #  class Contact < Base
  #  end

  #  class Folder < Entry
  #  end

  enum EncodingType
    ASCII
    UTF8
    UTF16
    Base64
  end

  enum MediaType
    Audio
    Video
    Picture
    Document
    Database
    Data
  end

  MEDIA_SUBTYPES = {
    MediaType::Audio    => Set{"mp3", "ogg", "wav"},
    MediaType::Video    => Set{"mp4", "webm"},
    MediaType::Document => Set{"pdf", "word"},
    MediaType::Picture  => Set{"png", "jpeg", "gif"},
    MediaType::Data     => Set{"json", "yaml", "xml", "csv"},
    MediaType::Database => Set{"sqlite3"},
  }

  class Media < Entry
    property bytesize : Int64
    property checksum : String
    property uri : String # scheme:[//[user:pass@]host[:port]][/]path[?query][#fragment]
    property media_type : MediaType
    property sub_type : String
    property encoding : EncodingType

    def comments : Hash(UUID, Comment)
      Hash(UUID, Comment).new
    end

    def reactions : Hash(UUID, Reaction)
      Hash(UUID, Reaction).new
    end
  end
end
