// Assoc list that will store handles to SmartObjects
// to avoid duplicating a ton of heavy I/O work needlessly.

# ifdef GOAI_LIBRARY_FEATURES
var/global/list/smartobject_cache
# endif

# ifdef GOAI_SS13_SUPPORT
GLOBAL_LIST_EMPTY(smartobject_cache)
# endif
