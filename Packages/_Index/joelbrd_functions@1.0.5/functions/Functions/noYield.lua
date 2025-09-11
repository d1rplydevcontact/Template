local Logger = require(script.Parent.Parent.Parent.Logger)

--[=[
    Wraps a callback in a task that will warn if the callback yields.

    Optionally before passing the callback, pass a `string` as the first argument to help provide context to the warning.

    - `context, callback, args...`
    - `callback, args...`
]=]
return function<T>(tracebackOrFunct: string | ((...any) -> ...T), functOrArg1: ((...any) -> ...T) | any, ...: any): ...T
    local args = { tracebackOrFunct, functOrArg1, ... }
    local context = typeof(args[1]) == "string" and args[1] :: string
    local callback = typeof(args[1]) == "function" and args[1]
        or typeof(args[2]) == "function" and args[2]
        or Logger.error(`Invalid arguments passed to noYield: {args}`)

    table.remove(args, 1)
    if context then
        table.remove(args, 1)
    end

    --

    local thread = coroutine.create(callback)
    local results = { coroutine.resume(thread, table.unpack(args)) }
    local success = table.remove(results, 1) :: boolean

    local traceback = debug.traceback(nil, 2)

    if coroutine.status(thread) == "suspended" then
        local source, line, name = debug.info(callback, "sln")

        coroutine.close(thread)

        Logger.error(
            `Yielding detected. \n{traceback}{context and `\n\n{context}` or ""}`
                .. `\n\n\nFunction defined at: {source}:{line}`
                .. if name == "" then "" else ` function {name}`
        )
    elseif not success then
        local source, line, name = debug.info(callback, "sln")

        Logger.error(
            `An error occurred while running a function. \n{traceback}{context and `\n\n{context}` or ""}`
                .. `\n\n\nFunction defined at: {source}:{line}`
                .. (if name == "" then "" else ` function {name}`)
                .. `\nError: {results[1]}`
        )
    end

    return table.unpack(results) :: T
end
