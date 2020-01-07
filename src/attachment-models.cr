require "./resource"

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

  # Additional content attached to the main content by an actor. The attachment is usually part of the main content's json file.
  abstract class Attachment < Resource
    property uuid : UUID
    property timestamp : Time # When
    property actor : Locator  # Who
    # def update(list : Hash(String, ::JSON::Any))
    # end
    # def properties(fields = {} of String => Bool, includes = [] of ResourceType) : { Hash(String, JSON::Any), Array(Locator)}
    #	list = {} of String => JSON::Any
    #	included = [] of Locator
    #	{list, included}
    # end
  end

  class Signature < Attachment
    property fields : Array(String)
    property checksum : String
    property keyid : String
    property signatory : Locator
    property hash : String
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
    Group
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
    # FIXME property privileges : IdentityUsage
    property public_key : String
  end

  enum MessageDeliveryStatus
    Delivered
    Acknowledged # Acknowlding that the message was Recieved and read
    Failed
  end

  class MessageDelivery < Attachment
    property recipient : Locator
    property status : MessageDeliveryStatus
  end
end
