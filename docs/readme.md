
## Main types

Message:
Notification <= Subscription : When something changes in the system (create/update/delete)
Actor: An account capable of executing actions
Content: set of sharable information that is persisted onto a json file with an arbitrary number of resource and can be interacted with.
Attachment: A data element in that can be attached to a MetaFile : it could have additional arbitrary fields,  markdown, html, image ...etc an attatchment has an actor and a unique id.
View: Made of blocks that use code to invoke other content and render them according to logic
Logic: Reusable logic that deals with content


### To generate a detailed structure 

```bash
crystal tool hierarchy -e Resource src/*-models.cr
crystal tool hierarchy -e Resource -f json src/*-models.cr | jq
crystal tool hierarchy -e Resource --no-color src/*-models.cr > docs/hierarchy
```
