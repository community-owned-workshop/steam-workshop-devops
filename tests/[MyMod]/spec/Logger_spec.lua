local Logger = require("[MyMod]/Logger")

describe("Logger", function()
    local originalPrint
    local originalEnabled

    before_each(function()
        originalPrint = _G.print
        originalEnabled = Logger.enabled
    end)

    after_each(function()
        _G.print = originalPrint
        Logger.enabled = originalEnabled
    end)

    it("prints enabled messages with its prefix", function()
        local output
        _G.print = function(message) output = message end
        Logger.enabled = true

        Logger.debug("hello")

        assert.are.equal("[MyMod] hello", output)
    end)

    it("does not print while disabled", function()
        local calls = 0
        _G.print = function() calls = calls + 1 end
        Logger.enabled = false

        Logger.debug("hello")

        assert.are.equal(0, calls)
    end)
end)
