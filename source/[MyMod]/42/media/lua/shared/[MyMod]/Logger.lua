local Logger = {}

Logger.enabled = true
Logger.prefix = "[MyMod]"


-- ---------------------------------------------------------------------------------------------------------------------
-- Prints a prefixed debug message when logging is enabled.
-- Values are converted with tostring so tables and nil can be inspected safely.
-- ---------------------------------------------------------------------------------------------------------------------

function Logger.debug(message)
    if Logger.enabled then
        print(Logger.prefix .. " " .. tostring(message))
    end
end


-- ---------------------------------------------------------------------------------------------------------------------

return Logger
