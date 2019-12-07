

## End-points

- `/graphql` and `/api` : GraphQL and REST interfaces to manage and serve content
- `/media` : Upload and download media (supports chunked upload/download) mainly for binaries but can be used for text as well.
- `/notifications` : WebSocket for Notifications and Status update, new events, user activities liking 'typing' ...etc.


## User Authentation 

Users must be "invited" by a priviledged member. With the invitation link they can use an OAuth2 provider (Gmail, Facebook, linkedin, twitter, ...etc) for authentication (signin and up).


## Operation types

### User operations

- Invite
- Login
- Logout

### Content operations

- Create
- Update
- Query
- Move
- Delete
- Interact

### Notification operations

- Subscribe 
- Unsubscribe
- Notify 

## Resrouce types

- Message
- Post
- Media
- Interaction/comment
- Folder (aka topic/category)
- Member (aka account/profile)
 
