require "./core-models"

module Edraj
  def self.trigger(notification : Notification)
    # TBD hash a subpath to deal with large number of notifications
    path = Edraj.settings.data_path / resource.space / resource.subpath / "changelog"
    Dir.mkdir_p path.to_s unless Dir.exists? path.to_s
    # uuid = UUID.random
    filename = "#{notification.timestamp.to_unix}.json"
    notification.to_json path, filename
  end
end
