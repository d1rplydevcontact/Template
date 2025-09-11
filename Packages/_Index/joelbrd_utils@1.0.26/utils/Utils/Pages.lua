local Pages = {}

function Pages.toTable(pages: Pages)
    local items = {}
    while true do
        table.insert(items, pages:GetCurrentPage())
        if pages.IsFinished then
            break
        end
        pages:AdvanceToNextPageAsync()
    end
    return items
end

return Pages
