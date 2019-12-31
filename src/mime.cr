module Edraj
  enum MediaType
    Audio
    Video
    Image
    Document
    Database
    Data
    Executable
    Binary # aka unknown
  end

  MEDIA_SUBTYPES = {
    MediaType::Audio    => Set{"mp3", "ogg", "wav"},
    MediaType::Video    => Set{"mp4", "webm"},
    MediaType::Document => Set{"pdf", "odt", "msword", "markdown", "plain", "html"},
    MediaType::Image    => Set{"png", "jpeg", "gif", "svg"},
    MediaType::Data     => Set{"json", "yaml", "xml", "csv"},
    MediaType::Archive  => Set{"zip", "tar", "tgz"},
    MediaType::Database => Set{"sqlite3"},
  }

  CONTENT_TYPE = {
    "application/pdf; charset=binary"                         => {type: MediaType::Document, sub: "pdf", extensions: ["pdf"]},
    "application/vnd.oasis.opendocument.text; charset=binary" => {type: MediaType::Document, sub: "odt", extensions: ["odt"]},
    "application/rtf; charset=binary"                         => {type: MediaType::Document, sub: "rtf", extensions: ["rtf"]},
    "image/jpeg; charset=binary"                              => {type: MediaType::Image, sub: "jpeg", extensions: ["jpg", "jpeg"]},
    "image/gif; charset=binary"                               => {type: MediaType::Image, sub: "gif", extensions: ["gif"]},
    "application/json; charset=utf-8"                         => {type: MediaType::Data, sub: "json", extensions: ["json"]},
    "application/xml; charset=utf-8"                          => {type: MediaType::Data, sub: "xml", extensions: ["xml"]},
    "application/yaml; charset=utf-8"                         => {type: MediaType::Data, sub: "yaml", extensions: ["yaml", "yml"]},
    "image/svg+xml; charset=us-utf-8"                         => {type: MediaType::Image, sub: "svg", extensions: ["svg"]},
    "audio/mpeg; charset=binary"                              => {type: MediaType::Audio, sub: "mpeg", extensions: ["mp3"]},
    "video/mp4; charset=binary"                               => {type: MediaType::Video, sub: "mp4", extensions: ["mp4"]},
    "application/gzip; charset=binary"                        => {type: MediaType::Archive, sub: "gzip", extensions: ["gz", "tgz"]},
    "application/zip; charset=binary"                         => {type: MediaType::Archive, sub: "zip", extensions: ["zip"]},
    "video/webm; charset=binary"                              => {type: MediaType::Video, sub: "webm", extensions: ["webm"]},
    "text/markdown; charset=utf-8"                            => {type: MediaType::Document, sub: "markdown", extensions: ["md"]},
    "text/plain; charset=utf-8"                               => {type: MediaType::Document, sub: "plain", extensions: ["text", "txt"]},
    "text/html; charset=utf-8"                                => {type: MediaType::Document, sub: "html", extensions: ["html", "html"]},
    "application/octet-stream; charset=binary"                => {type: MediaType::Binary, sub: "unknown", extensions: [] of String},
    "application/vnd.ms-htmlhelp; charset=binary"             => {type: MediaType::Document, sub: "chm", extensions: ["chm"]}, # Compiled HTML
    "image/tiff; charset=binary"                              => {type: MediaType::Image, sub: "tiff", extensions: ["tiff"]},
    "audio/ogg; charset=binary"                               => {type: MediaType::Audio, sub: "ogg", extensions: ["ogg", "opus"]}, # OGG Opus
    "application/msword; charset=binary"                      => {type: MediaType::Document, sub: "msword", extensions: ["doc", "docx"]},
  }
end
