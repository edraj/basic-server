# Edraj 

Information management and exchange system.

Edraj presents a simplified approach for an all-in-one information system. 

Imagine combining the following popular services:

- Messaging (email and IM like) (with federation)
- Content Management System for publishing and collaborating on producing content
- Follow / Consume news and updates on various types of activiteis with granular control. RSS like. 
- Maintain your valuable digital assets (media, documents ...). Think dropbox and gang. 
- Enriched with meta-data 

With emphasis on
- All "golden" information is strictly persisted in version-controlled flat-file form. 
- Information schema and schema validation
- Access entitlement

## Break down of the application layers

- Information persistence layer (strictly file-based and version controlled by git). 
- Indexing/caching layer that interfaces with the golden-store
- API layer that services the information 
- UI layer (Web, Mobile/Desktop app)

## General principles

- As reasonably possible, each actor's interaction is represented in a separate file with timestamp and reference to the actor and signature if availble.
- Identity: a Universally Uniquely identifiable entity: User, Content ...etc.
- Each update should result in a new revision file created under the attic
- Actor is an active identity capable of making actions: User, Member, Guest, Device, Application. 
- Entries are hirarchical 
- Light-weight and self-hosted
- Federation


## Information Persistence (aka Golden store)

  - File/Folder based 
  - Meta data enabled
  - Structured json whereever applicable
  - Version controlled (git gives a basic transaction concept)

  This allows the information to become time-proof and be liberated from the boundereies of the applictions. i.e. any application can consume the information and update it (in it's golden form). This also makes it easy to sync and backup data across multiple. 

## Main Sections

- **Identity Management** (admin)
		- **Schema definitions** 
		- **Profile** Management (Self)
				- Registered / verified oauth2 services tokens
        - Signature keys
				- Self info and contact details 
				- Invitations made to others
				- Personal messages (inbox)
				- Contact-list to other people
- **Spaces** (Admin) Each space is an independent self-contained structure of content that revolves around a core topic or interest. 
		- **Schema definitions** 
    - **Members** 
        - A pointer to the actual member profile.
    - **Groups**
    - **Access control**: 
        - **Roles** : Sets of permissions
        - **Permissions** : Parameterized security rules
        - **Entitlements**
        - public/private
		- **Pages**
				- Web-enabled public and private access to servicing the data to other users and for indexing by search engines.
				- Active-notebook like (think jypiter) 
		- **Messages**
				- Topics/categories/...
        - Threads (messages within a topic are grouped by thread-id)
		- **Notifications**
				- According to a filter (type, actor, group, topic, tag, keyword, ..etc)
				- Typing message/response
				- Login/logout status (onliness)
		- **Interactions** How other users interact with the content.
				- Reactions
				- Suggested Changes
				- Comments
				- Shares
				- Views
    - **Entries** 
        - `meta.json`
        - `content.json`
        - `/attachments`
						- `/{folders}/{filename}`
            - `/{folders}/meta.{filename}.json`
        - `/interactions/reactions`
						- `/{uuid}.json`
        - `/interactions/comments`
						- `/{uuid}.json`
        - `/interactions/shares` # also used to distribute content delivery
						- `/{uuid}.json`
        - `/interactions/views` 
						- `/{uuid}.json`
        - `{subentries}`
		- **Rules** (aka active logic)
				- Rules to be executed upon certain events


## Initial / Reference implementation notes

Edraj can and shall have several implementations all implementations must be able to:
- Feed from and interact the same file-based information store
- Offer compatible API layer. 

The Initial / refrence implementation uses the following technologies

- Redis for all caching / speed improvements. Leveraging Redis's advanced capabilities beyond a regular KV store such as Streams, Free text document indexes, JSON and so forth.
- Crystal language for writing the backend and command line tools
- Svelte for the basic front-end


### Further implementation notes

- The root data folder path should be expored with $IYIPATH environment variable. 
- $IYIPATH/data is maintained in a separate git repo. Later on each space can be maintained as a git module.



## API 

(see)[docs/api.md]



