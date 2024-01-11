local circleRadius = 14
local circle_color = Color( 100, 255, 0, 65 )

local DrawCircles
do
    local math_ceil = math.ceil
    local table_insert = table.insert
    local math_rad = math.rad
    local math_sin = math.sin
    local math_cos = math.cos
    local surface_DrawPoly = surface.DrawPoly
    local surface_SetDrawColor = surface.SetDrawColor
    local cam_Start3D2D = cam.Start3D2D
    local cam_End3D2D = cam.End3D2D
    local ang_zero = Angle( 0, 0, 0 )

    local cachedCircle

    local function drawCircle( x, y, radius, seg )
        local newCircle = {}

        table_insert( newCircle, { x = x, y = y, u = 0.5, v = 0.5 } )
        for i = 0, seg do
            local a = math_rad( (i / seg) * -360 )
            table_insert( newCircle, {
                x = x + math_sin( a ) * radius,
                y = y + math_cos( a ) * radius,
                u = math_sin( a ) / 2 + 0.5,
                v = math_cos( a ) / 2 + 0.5
            } )
        end

        local a = math_rad( 0 )
        table_insert( newCircle, {
            x = x + math_sin( a ) * radius,
            y = y + math_cos( a ) * radius,
            u = math_sin( a ) / 2 + 0.5,
            v = math_cos( a ) / 2 + 0.5
        } )

        return newCircle
    end

    -- Function to draw circles between two points
    DrawCircles = function( startPos, endPos )
        local circle = cachedCircle or drawCircle( 0, 0, circleRadius, 50 )
        cachedCircle = circle

        endPos[3] = startPos[3]

        local dir = (endPos - startPos):GetNormalized()
        local distance = startPos:Distance( endPos )
        local angle = dir:Angle()

        -- Draw rectangle
        cam_Start3D2D( startPos, angle, 1 )
        surface_SetDrawColor( 50, 255, 0, 120 )
        local radius = circleRadius
        local lineThickness = radius / 3
        surface.DrawRect(
            0,
            -(lineThickness / 2),
            math_ceil( distance - radius + 1 ),
            radius / 3
        )
        cam_End3D2D()

        -- draw destination circle
        cam_Start3D2D( endPos, ang_zero, 1 )
        surface_SetDrawColor( circle_color )
        surface_DrawPoly( circle )
        cam_End3D2D()
    end
end

local function makeGhost()
    local ghost = ClientsideModel( LocalPlayer():GetModel(), RENDERGROUP_TRANSLUCENT )
    ghost:Spawn()

    local seq = ghost:LookupSequence( "idle_magic" )
    ghost:SetSequence( seq )
    ghost:SetRenderMode( RENDERMODE_TRANSCOLOR )
    ghost:SetColor4Part( 255, 255, 255, 200 )
    ghost:SetRenderFX( 10 )

    return ghost
end

local Picker = { selecting = false }

local function DrawGhost( startPoint, currentEnd )
    local ghost = Picker.ghost

    if not ghost then return end
    local dir = (startPoint - currentEnd):Angle()
    dir[1] = 0
    dir[3] = 0

    ghost:SetPos( currentEnd )
    ghost:SetAngles( dir )
end

local function getScreenPos()
    local view = fSpectate.getCalcView()
    local specEnt = fSpectate.getSpecEnt()

    return util.QuickTrace(
        view.origin,
        view.angles:Forward() * 10000,
        specEnt
    ).HitPos
end


hook.Add( "PostDrawOpaqueRenderables", "FSpectate_TeleportSelector", function()
    if not Picker.selecting then return end

    local startPoint = Picker.focusEnt:GetPos()
    local currentEnd = getScreenPos()
    DrawCircles( startPoint, currentEnd )
    DrawGhost( startPoint, currentEnd )
end )

local last
function Picker:GetThirdPersonPos( ent )
    if not last then
        last = fSpectate.getThirdPersonPos( ent )
    end

    local aimvector = self.lockedAimVec
    local startPos = ent:IsPlayer() and ent:GetShootPos() or ent:LocalToWorld( ent:OBBCenter() )
    local endpos = startPos - aimvector * 650
    local specEnt = fSpectate.getSpecEnt()

    local tracer = {
        start = startPos,
        endpos = endpos,
        filter = specEnt
    }

    local trace = util.TraceLine( tracer )

    local new = LerpVector( CurTime() - self.selecting, last, trace.HitPos + trace.HitNormal * 10 )
    last = new

    return new
end


function Picker:Start( focusEnt )
    last = nil
    self.focusEnt = focusEnt
    self.selecting = CurTime()
    self.ghost = makeGhost()
    self.lockedAimVec = LocalPlayer():GetAimVector()
end

function Picker:Stop()
    if self.ghost then self.ghost:Remove() end
    local chosen = getScreenPos()

    last = nil
    self.selecting = false

    return chosen
end

return Picker
