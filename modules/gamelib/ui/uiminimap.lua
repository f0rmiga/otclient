function UIMinimap:onSetup()
  self.flagWindow = nil
  self.flagsWidget = self:getChildById('flags')
  self.floorUpWidget = self:getChildById('floorUp')
  self.floorDownWidget = self:getChildById('floorDown')
  self.zoomInWidget = self:getChildById('zoomIn')
  self.zoomOutWidget = self:getChildById('zoomOut')
  self.dx = 0
  self.dy = 0
  self.onPositionChange = function() self:followLocalPlayer() end
  self.onAddAutomapFlag = function(pos, icon, description) self:addFlag(pos, icon, description) end
  self.onRemoveAutomapFlag = function(pos, icon, description) self:addFlag(pos, icon, description) end
  connect(g_game, {
    onAddAutomapFlag = self.onAddAutomapFlag,
    onRemoveAutomapFlag = self.onRemoveAutomapFlag,
  })
  connect(LocalPlayer, { onPositionChange = self.onPositionChange })
end

function UIMinimap:onDestroy()
  disconnect(LocalPlayer, { onPositionChange = self.onPositionChange })
  disconnect(g_game, {
    onAddAutomapFlag = self.onAddAutomapFlag,
    onRemoveAutomapFlag = self.onRemoveAutomapFlag,
  })
  self:destroyFlagWindow()
end

function UIMinimap:load()
  local settings = g_settings.getNode('Minimap')
  if settings then
    if settings.flags then
      for i=1,#settings.flags do
        local flag = settings.flags[i]
        self:addFlag(flag.position, flag.icon, flag.description)
      end
    end
    self:setZoom(settings.zoom)
  end
  self:updateFlags()
end

function UIMinimap:save()
  local settings = { flags={} }
  local children = self.flagsWidget:getChildren()
  for i=1,#children do
    local flag = children[i]
    table.insert(settings.flags, {
      position = flag.pos,
      icon = flag.icon,
      description = flag.description,
    })
  end
  settings.zoom = self:getZoom()
  g_settings.setNode('Minimap', settings)
end

function UIMinimap:addFlag(pos, icon, description)
  local flag = self:getFlag(pos, icon, description)
  if flag then
    return
  end
  
  flag = g_ui.createWidget('MinimapFlag', self.flagsWidget)
  flag.pos = pos
  flag.icon = icon
  flag.description = description
  flag:setIcon('/images/game/minimap/flag' .. icon)
  flag:setTooltip(description)
  flag.onMouseRelease = function(widget, pos, button)
    if button == MouseRightButton then
      local menu = g_ui.createWidget('PopupMenu')
      menu:addOption(tr('Delete mark'), function() widget:destroy() end)
      menu:display(pos)
      return true
    end
    return false
  end

  self:updateFlag(flag)
end

function UIMinimap:getFlag(pos, icon, description)
  local children = self.flagsWidget:getChildren()
  for i=1,#children do
    local flag = children[i]
    if flag.pos.x == pos.x and flag.pos.y == pos.y and flag.pos.z == pos.z and flag.icon == icon and flag.description == description then
      return flag
    end
  end
end

function UIMinimap:removeFlag(pos, icon, description)
  local flag = self:getFlag(pos, icon, description)
  if flag then
    flag:destroy()
  end
end

function UIMinimap:updateFlag(flag)
  local topLeft, bottomRight = self:getArea()
  if self:isFlagVisible(flag, topLeft, bottomRight) then
    flag:setVisible(true)
    flag:setMarginLeft(-5.5 + (self:getWidth() / (bottomRight.x - topLeft.x)) * (flag.pos.x - topLeft.x))
    flag:setMarginTop(-5.5 + (self:getHeight() / (bottomRight.y - topLeft.y)) * (flag.pos.y - topLeft.y))
  else
    flag:setVisible(false)   
  end
end

function UIMinimap:updateFlags()
  local children = self.flagsWidget:getChildren()
  for i=1,#children do
    self:updateFlag(children[i])
  end
end

UIMinimap.realZoomIn = UIMinimap.zoomIn
function UIMinimap:zoomIn()
  self:realZoomIn()
  self:updateFlags()
end

UIMinimap.realZoomOut = UIMinimap.zoomOut
function UIMinimap:zoomOut()
  self:realZoomOut()
  self:updateFlags()
end

function UIMinimap:floorUp(floors)
  local pos = self:getCameraPosition()
  pos.z = pos.z - floors
  if pos.z >= FloorHigher then
    self:setCameraPosition(pos)
  end
  self:updateFlags()
end

function UIMinimap:floorDown(floors)
  local pos = self:getCameraPosition()
  pos.z = pos.z + floors
  if pos.z <= FloorLower then
    self:setCameraPosition(pos)
  end
  self:updateFlags()
end

function UIMinimap:followLocalPlayer()
  local player = g_game.getLocalPlayer()
  self:followCreature(player)
  self:updateFlags()
end

function UIMinimap:reset()
  self:followLocalPlayer()
  self:setZoom(0)
end

function UIMinimap:move(x, y)
  local topLeft, bottomRight = self:getArea()
  self.dx = self.dx + ((bottomRight.x - topLeft.x) / self:getWidth() ) * x
  self.dy = self.dy + ((bottomRight.y - topLeft.y) / self:getHeight()) * y
  local dx = math.floor(self.dx)
  local dy = math.floor(self.dy)
  self.dx = self.dx - dx
  self.dy = self.dy - dy

  local cameraPos = self:getCameraPosition()
  local pos = {x = cameraPos.x - dx, y = cameraPos.y - dy, z = cameraPos.z}
  self:setCameraPosition(pos)
  self:updateFlags()
end

function UIMinimap:onMouseWheel(mousePos, direction)
  local keyboardModifiers = g_keyboard.getModifiers()
  if direction == MouseWheelUp and keyboardModifiers == KeyboardNoModifier then
    self:zoomIn()
  elseif direction == MouseWheelDown and keyboardModifiers == KeyboardNoModifier then
    self:zoomOut()
  elseif direction == MouseWheelDown and keyboardModifiers == KeyboardCtrlModifier then
    self:floorUp(1)
  elseif direction == MouseWheelUp and keyboardModifiers == KeyboardCtrlModifier then
    self:floorDown(1)
  end
  self:updateFlags()
end

function UIMinimap:onMousePress(pos, button)
  if not self:isDragging() then
    self.allowNextRelease = true
  end
end

function UIMinimap:onMouseRelease(pos, button)
  -- TODO:
  --if not self.allowNextRelease then return true end
  self.allowNextRelease = false

  local mapPos = self:getPosition(pos)
  if not mapPos then return end

  if button == MouseLeftButton then
    local player = g_game.getLocalPlayer()
    if not player:autoWalk(mapPos) then
      player.onAutoWalkFail = function() modules.game_textmessage.displayFailureMessage(tr('There is no way.')) end
    end
    return true
  elseif button == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:addOption(tr('Create mark'), function() 
        self:createFlagWindow(mapPos)
    end)
    menu:display(pos)
    return true
  end
  return false
end

function UIMinimap:onDragEnter(pos)
  return true
end

function UIMinimap:onDragMove(pos, moved)
  self:move(moved.x, moved.y)
  return true
end

function UIMinimap:onDragLeave(widget, pos)
  return true
end

function UIMinimap:createFlagWindow(pos)
  if self.flagWindow then return end
  if not pos then return end

  self.flagWindow = g_ui.createWidget('MinimapFlagWindow', rootWidget)

  local positionLabel = self.flagWindow:getChildById('position')
  local description = self.flagWindow:getChildById('description')
  local okButton = self.flagWindow:getChildById('okButton')
  local cancelButton = self.flagWindow:getChildById('cancelButton')

  positionLabel:setText(string.format('%i, %i, %i', pos.x, pos.y, pos.z))

  local flagRadioGroup = UIRadioGroup.create()
  for i=0,19 do
    local checkbox = self.flagWindow:getChildById('flag' .. i)
    checkbox.icon = i
    flagRadioGroup:addWidget(checkbox)
  end
  
  flagRadioGroup:selectWidget(flagRadioGroup:getFirstWidget())
  
  okButton.onClick = function() 
      self:addFlag(pos, flagRadioGroup:getSelectedWidget().icon, description:getText())
      self:destroyFlagWindow()
    end
  cancelButton.onClick = function()
      self:destroyFlagWindow()
    end

  self.flagWindow.onDestroy = function() flagRadioGroup:destroy() end
end

function UIMinimap:destroyFlagWindow()
  if self.flagWindow then
    self.flagWindow:destroy()
    self.flagWindow = nil
  end
end

function UIMinimap:getArea()
  local topLeft = self:getPosition({ x = self:getX() + 1, y = self:getY() + 1 })
  local bottomRight = self:getPosition({ x = self:getX() + self:getWidth() - 2, y = self:getY() + self:getHeight() - 2 })
  return topLeft, bottomRight
end

function UIMinimap:isFlagVisible(flag, topLeft, bottomRight)
  return flag.pos.x >= topLeft.x and flag.pos.x <= bottomRight.x and flag.pos.y >= topLeft.y and flag.pos.y <= bottomRight.y and flag.pos.z == topLeft.z
end
