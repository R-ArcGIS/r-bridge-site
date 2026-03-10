#' Portal users and groups
#'
#' The {arcgisutils} package provides utility functions for working with your
#' portal.
#'
#' portal related function documentation is at https://developers.arcgis.com/r-bridge/api-reference/arcgisutils/#portal
#'
#' - You may want to get individual user information. TODO find motivation why
#' - you may want to get all members in a group
#'
#' For many of the portal related functionality you will need to be authenticated to
#' your portal.
library(arcgisutils)

#' we use the below to authenticate to our portal as ourself
#' then we set the authentication token to be available for our entire session
set_arc_token(auth_user())

#' we can search for individual users based on their username
josiah <- arc_user("jparry_ANGP")
josiah

#' arc_user() returns a PortalUser object
#' This is a list with a fancy print method
#' there are many fields available to in the user object
names(josiah)

#' for example we can see what groups josiah is in by pulling the title column out of the
#' groups data.frame
josiah$group$title


#' we can get all of the users in a portal by using `arc_portal_users()`
all_portal_users <- arc_portal_users()

# print a subset to see the id, usertype, and created and modifeid at dates
all_portal_users[c("id", "userType", "created", "modified")]

# we can take these user IDs and fetch individual users for them
# as a derived example filter and subset to josiah's portal ID
josiah_id <- subset(
  all_portal_users,
  username == "jparry_ANGP",
  select = "id",
  drop = TRUE
)

arc_user(josiah_id)

#' you can use this with any number of IDs

#' for groups, if you have the group ID you can get metadata about the group
web_app_templates <- arc_group("2f0ec8cb03574128bd673cefab106f39")
str(web_app_templates, 1)


# Content Listings -------------------------------------------------------

#' There are 3 ways to get content listings for a portal:
#'
#' - arc_group_content() gets all content items for a group
#' - arc_user_content() gets all content items for a user

group_items <- arc_group_content(web_app_templates)
group_items


# in addition to group content items we can get content for specific users
# to get your own content items you can use the `arc_user_self()` function
self <- arc_user_self()

# we can then use the username from the signed in token to fetch that user's items
arc_user_content(self$username)


# alternatively you can use full text search. by default this searches AGOL
# to search your private or enterprise portal set your `ARCGIS_HOST` environment variable
#' it will then search that
#'
#' search_items() uses pagination to handle large search results
#' by default it fill fetch all pages of a query
#' We provide a query as the first argument
search_items(
  query = "crime",
  max_pages = 1
)

#' we can use the `item_type` argument to specify what type of results we want.
#' use `portal_item_types()` to see all valid item_types (there are a ton)
#' set `item_type = "Feature Service"` to search only feature services
crime_items <- search_items(
  query = "crime",
  item_type = "Feature Service",
  max_pages = 1
)

# you can extract the ID of these and pass them to arc_open()
library(arcgislayers)

arc_open(crime_items$id[1])
