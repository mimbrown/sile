SILE.tateFramePrototype = pl.class({
    _base = SILE.framePrototype,
    direction = "TTB-RTL",
    enterHooks = {
      function (self)
        self.oldtypesetter = SILE.typesetter
        SILE.typesetter.leadingFor = function(_, v)
          v.height = SILE.length("1zw"):absolute()
          local bls = SILE.settings.get("document.baselineskip")
          local d = bls.height:absolute() - v.height
          local len = SILE.length(d.length, bls.height.stretch, bls.height.shrink)
          return SILE.nodefactory.vglue({height = len})
        end
        SILE.typesetter.breakIntoLines = SILE.require("packages/break-firstfit").exports.breakIntoLines
      end
    },
    leaveHooks = {
      function (self)
        SILE.typesetter = self.oldtypesetter
      end
    }
  })

SILE.newTateFrame = function (spec)
  return SILE.newFrame(spec, SILE.tateFramePrototype)
end

SILE.registerCommand("tate-frame", function (options, _)
  SILE.documentState.thisPageTemplate.frames[options.id] = SILE.newTateFrame(options)
end, "Declares (or re-declares) a frame on this page.")

local outputLatinInTate = function (self, typesetter, line)
  -- My baseline moved
  typesetter.frame:advanceWritingDirection(SILE.measurement("-0.5zw"))
  typesetter.frame:advancePageDirection(SILE.measurement("0.25zw"))

  local vorigin = -typesetter.frame.state.cursorY
  self:oldOutputYourself(typesetter,line)
  typesetter.frame.state.cursorY = -vorigin
  typesetter.frame:advanceWritingDirection(self:lineContribution())
  -- My baseline moved
  typesetter.frame:advanceWritingDirection(SILE.measurement("0.5zw") )
  typesetter.frame:advancePageDirection(-SILE.measurement("0.25zw"))
end


local outputTateChuYoko = function (self, typesetter, line)
  -- My baseline moved
  local em = SILE.measurement("1zw")
  typesetter.frame:advanceWritingDirection(-em + em/4 - self:lineContribution()/2)
  typesetter.frame:advancePageDirection(2*self.height - self.width/2)
  self:oldOutputYourself(typesetter,line)
  typesetter.frame:advanceWritingDirection(-self:lineContribution()*1.5+self.height*3/4)

end
-- Eventually will be automatically called by script detection, but for now
-- called manually
SILE.registerCommand("latin-in-tate", function (_, content)
  local nodes
  local oldT = SILE.typesetter
  local prevDirection = oldT.frame.direction
  if oldT.frame:writingDirection() ~= "TTB" then return SILE.process(content) end
  SILE.require("packages/rotate")
  SILE.settings.temporarily(function()
    local latinT = SILE.defaultTypesetter {}
    latinT.frame = SILE.framePrototype({}, true) -- not fully initialized, just a dummy
    latinT:initState()
    SILE.typesetter = latinT
    SILE.settings.set("document.language", "und")
    SILE.settings.set("font.direction", "LTR")
    SILE.process(content)
    nodes = SILE.typesetter.state.nodes
    SILE.typesetter:shapeAllNodes(nodes)
    SILE.typesetter.frame.direction = prevDirection
  end)
  SILE.typesetter = oldT
  SILE.typesetter:pushGlue({
    width = SILE.length("0.5zw", "0.25zw", "0.25zw"):absolute()
  })
  for i = 1,#nodes do
    if SILE.typesetter.frame:writingDirection() ~= "TTB" then
      SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes+1] = nodes[i]
    elseif nodes[i].is_glue then
      nodes[i].width = nodes[i].width
      SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes+1] = nodes[i]
    elseif nodes[i]:lineContribution():tonumber() > 0 then
      SILE.call("hbox", {}, function ()
        SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes+1] = nodes[i]
      end)
      local n = SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes]
      -- Turn off all complex flags.
      for j = 1,#(n.value) do
        for k = 1,#(n.value[j].nodes) do
          n.value[j].nodes[k].value.complex = false
        end
      end
      n.oldOutputYourself = n.outputYourself
      n.outputYourself = outputLatinInTate
    end
  end
end, "Typeset rotated Western text in vertical Japanese")

SILE.registerCommand("tate-chu-yoko", function (_, content)
  if SILE.typesetter.frame:writingDirection() ~= "TTB" then return SILE.process(content) end
  -- SILE.typesetter:pushGlue({
  --   width = SILE.length.new({length = SILE.toPoints("0.5zw"),
  --                            stretch = SILE.toPoints("0.25zw"),
  --                             shrink = SILE.toPoints("0.25zw")
  --                           })
  -- })
  SILE.settings.temporarily(function()
    SILE.settings.set("document.language", "und")
    SILE.settings.set("font.direction", "LTR")
    SILE.call("rotate",{angle =-90}, function ()
      SILE.call("hbox", {}, content)
      local n = SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes]
      n.misfit = true
      n.oldOutputYourself = n.outputYourself
      n.outputYourself = outputTateChuYoko
    end)

  end)
  -- SILE.typesetter:pushGlue({
  --   width = SILE.length.new({length = SILE.toPoints("0.5zw"),
  --                            stretch = SILE.toPoints("0.25zw"),
  --                             shrink = SILE.toPoints("0.25zw")
  --                           })
  -- })

end)


return {
  init = function (_, _)
    -- Japaneese language support defines units which are useful here
    SILE.require("packages/font-fallback.lua")
    SILE.call("font:add-fallback", { family = "Noto Sans CJK JP" })
    SILE.languageSupport.loadLanguage("ja")
  end,
  documentation = [[
\begin{document}
The \code{tate} package provides support for Japanese vertical typesetting.
It allows for the definition of vertical-oriented frames, as well
as for two specific typesetting techniques required in vertical
documents: \code{latin-in-tate} typesets its content as Latin
text rotated 90 degrees, and \code{tate-chu-yoko} places (Latin)
text horizontally within a single grid-square of the vertical \em{hanmen}.
\end{document}
]]
}
