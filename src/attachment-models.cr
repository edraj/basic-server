module Edraj
  enum AttachmentType
    Reply # aka comment
    Reaction
    SuggestedModification
    Share
    Media
    Signature
    Relationship
    Subscription
    Invitation
    # Token
    # Notification
    # Locator
    # Location # Aka Address
    Address
    Block
    Organization
  end

  class Attachment
    include JSON::Serializable
    property uuid : UUID
    property timestamp : Time # When
    property actor : Locator  # Who
  end

  class Relationship < Attachment
    property type : String
    property properties = {} of String => JSON::Any
    property related_to : Locator
  end

  class Signature < Attachment
    property fields : Array(String)
    property checksum : String
    property keyid : String
    property signatory : Locator
    property hash : String
  end

  class Subscription < Attachment
    property subpath = ""
    property resource_types = [] of ContentType
    property tags = [] of String

    def initialize(@owner)
    end
  end

  enum ReactionType
    Agreed
    Seen
    Like
    Love
    Dislike
    Laugh
    Angry
    Sad
    Report # aka Inappropriate
  end

  class Share < Attachment
    property location : Locator
  end

  class Reaction < Attachment
    property reaction_type : ReactionType
  end

  class Reply < Attachment
    property body : JSON::Any
    property media = Array(Media).new
  end

  class SuggestedModification < Attachment # Phrasing / Information / Addition / Removal
    property original
    property suggested
    property replies = [] of Reply
    property status # New, Accepted, Rejected, Replied (commented)
  end

  class Invitation < Attachment
  end

  class Media < Attachment
    property bytesize : Int64
    property checksum : String
    property uri : String? # scheme:[//[user:pass@]host[:port]][/]path[?query][#fragment]
    property filename : String
    property content_type : String

    # property media_type : MediaType
    # property subtype : String
    # property encoding : EncodingType::None
    def media_type
      MEDIA_TYPE[@content_type]
    end

    def initialize(@actor, space, subpath, filename, uri = nil)
      path = Edraj.settings.data_path / "spaces" / space / subpath / filename
      raise "File doesn't exist #{subpath}/#{filename}" if (!File.exists?(path) || !File.readable?(path))
      @content_type = `file -Ebi #{path}`.strip
      @content_type.sub "; charset=us-ascii", "; charset=utf-8"
      @bytesize = `du --bytes #{path} | cut -f 1 `.to_i64
      @checksum = `sha512sum #{path} | cut -f 1 -d ' '`.strip
      # FIXME read timestamp from file
      @filename = filename
    end
  end

  enum EncodingType
    None
    ASCII
    UTF8
    UTF16
    Base64
  end

  class Address < Attachment
    property line : String
    property zipcode : String
    property city : String
    property state : String
    property countery : String
    property geopoint : NamedTuple(long: Float64, lat: Float64)?
  end

  enum ContactType
    Mobile
    Email
    Landphone
    SocialMedia
  end

  class ContactDetail
    include JSON::Serializable
    property type : ContactType
    property handler : String # for social media full handler e.g. fb.com/kefahi or linkedin/in/kefahi
  end

  enum IdentityType
    Device
    Application
    Browser
    Bot
    Human
  end

  @[Flags]
  enum IdentityUsage
    Sign
    Issue
    Encrypt
    Authenticate
    Certify
  end

  class Organization < Attachment
    property shortname : String
    property displayname : String
    property uri = [] of String
    property logo : Media
  end

  enum AccomplishmentType
    WorkExperience
    Degree
    Certificate
    Product     # Produce
    Recognition # Award / Honors
  end

  class Accomplishment < Attachment
    property type : AccomplishmentType
    property description : String
    property date_earned : Time?
    property duration : String? # Date range / span
    property organization : Organization?
    property role : String? # Paticipant, founder, inventor, composer, author, manager ....

  end

  class Identity < Attachment
    property type : IdentityType
    property privileges : IdentityUsage
    property public_key : String
  end
end
