require "json"
require "uuid"
require "uuid/json"
require "./config"

module Edraj

  enum ResourceType
    Post
    Message
    Task
    Term
    Media
    Folder
    Contact
    Notification
    Invitation
    Comment
    Profile
    Reaction
    Subscription
    Schema
    Token
    Other
  end

	enum ScopeType
		Base
		Oneleve
		Subtree
	end

  class Locator
    include JSON::Serializable
		property type : ResourceType
		property uuid : UUID
		property local_path : String
		property remote_path : String
  end

  class Signature
    include JSON::Serializable
    property fields : Array(String)
    property timestamp : Time
    property checksum : String
    property key : String
    property actor : UUID
    property hash : String

    def verify : Bool
    end
  end

  class Base
    include JSON::Serializable
    property uuid : UUID
    property timestamp : Time
    property signature : Signature?
    property author : UUID?
    property parent_uuid : UUID
  end

  class Entry < Base
    property shortname : String
    property displayname : String
    property description : String?
    property tags = Array(String).new

    def comments : Hash(UUID, Comment)
      Hash(UUID, Comment).new
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
    property type : ReactionType
  end

  class Comment < Base
    property body : String

    def comments : Hash(UUID, Comment)
      Hash(UUID, Comment).new
    end

    def reactions : Hash(UUID, Reaction)
      Hash(UUID, Reaction).new
    end

    def media : Hash(UUID, Media)
      Hash(UUID, Media).new
    end
  end

  class Message < Base
		property subject : String?
		property body : String
    property from : UUID
    property to : Array(UUID)
    property thread_id : UUID


		# Read one
		def self.load(parent_path, sub_path, uuid)
			Message.from_json File.read Edraj.settings.data_path / parent_path / sub_path / "#{uuid}.json"
		end
  end

  class Contact < Base
  end

  class Folder < Entry
  end

	enum EncodingType
		UTF8
		Base64
	end

  enum MediaType
    Audio
    Video
    Picture
    Document
    Data
  end

  MEDIA_SUBTYPES = {
    MediaType::Audio    => Set{"mp3", "ogg", "wav"},
    MediaType::Video    => Set{"mp4", "webm"},
    MediaType::Document => Set{"pdf", "word"},
    MediaType::Picture  => Set{"png", "jpeg", "gif"},
    MediaType::Data     => Set{"json", "yaml", "xml", "csv"},
  }

  # URI : scheme:[//[user:password@]host[:port]][/]path[?query][#fragment]
  class Media < Entry
    property bytesize : Int64
    property checksum : String
    property uri : String
    property type : MediaType
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
