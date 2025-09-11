local functions = {
    forceGarbageCollection = require(script.Functions.forceGarbageCollection),
    getPlayerChatColor = require(script.Functions.getPlayerChatColor),
    isInstanceDestroyed = require(script.Functions.isInstanceDestroyed),
    noYield = require(script.Functions.noYield),
    uuid = require(script.Functions.uuid),
    client = {
        exportCopyPasteLongString = require(script.Functions.client.exportCopyPasteLongString),
        getHardwareSafeAreaInsets = require(script.Functions.client.getHardwareSafeAreaInsets),
    }
}

return functions
