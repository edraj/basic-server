
CREATE TABLE IF NOT EXISTS identity (
	guid TEXT PRIMARY KEY NOT NULL, 
	shortname TEXT NOT NULL UNIQUE, 
	prettyname TEXT,
  created_at TEXT,
	updated_at TEXT
);

-- CREATE TABLE identities_keys (
-- 	guid TEXT PRIMARY KEY NOT NULL, 
--	identity_guid TEXT NOT NULL, 
--	fingerprint TEXT NOT NULL UNIQUE, 
--	status TEXT NOT NULL, 
--	FOREIGN KEY (identity_guid) REFERENCES identities (guid) ON DELETE CASCADE ON UPDATE NO ACTION
-- );

CREATE TABLE entry (
	guid TEXT PRIMARY KEY NOT NULL, 
	subpath TEXT NOT NULL, 
	shortname TEXT NOT NULL, 
	schema_id TEXT NOT NULL, 
	location TEXT NOT NULL, 
	byte_size INTEGER NOT NULL, 
	checksum TEXT NOT NULL,
	-- media_type TEXT NOT NULL, 
  -- encoding TEXT NOT NULL,
	tags TEXT, 
	categories TEXT,
	created_at TEXT,
	updated_at TEXT,
  UNIQUE (subpath, shortname)
);

CREATE TABLE IF NOT EXISTS attachment (
	guid TEXT PRIMARY KEY NOT NULL, 
	entry_guid TEXT NOT NULL, 
	subpath TEXT NOT NULL, 
	shortname TEXT NOT NULL, 
	location TEXT NOT NULL,
	checksum TEXT NOT NULL, 
	byte_size INTEGER NOT NULL,
	media_type TEXT NOT NULL, 
	-- encoding TEXT NOT NULL,
	tags TEXT, 
	categories TEXT,
	created_at TEXT,
	updated_at TEXT,
	FOREIGN KEY (entry_guid) REFERENCES entries (guid), --  ON DELETE CASCADE ON UPDATE NO ACTION,
  UNIQUE (subpath, shortname)
);


-- CREATE TABLE signatures (actor: TEXT, checksum: TEXT);
-- CREATE TABLE revisions (content_id: TEXT, timestamp: TEXT,  actor: TEXT);

