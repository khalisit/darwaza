/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // add "active" boolean field with default = true
  collection.fields.addAt(9, new Field({
    "hidden": false,
    "id": "bool_active_001",
    "name": "active",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "bool"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // remove "active" field
  collection.fields.removeById("bool_active_001")

  return app.save(collection)
})
