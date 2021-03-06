require "Helper"
require "Manager"
require "GlobalVariables"

AttackManager = List.new()

--攻击对象判定
function solveAttacks(dt)
    for val = AttackManager.last, AttackManager.first, -1 do
        local attack = AttackManager[val] --看看这个attackmanager是什么？？,这个应该是管理具体攻击类型信息的
        local apos = getPosTable(attack)
        --如果是英雄发出攻击
        if attack.mask == EnumRaceType.HERO then
            --如果是英雄发出的攻击，则检测所有的怪物
            for mkey = MonsterManager.last, MonsterManager.first, -1 do
                --首先检测距离是否满足
                local monster = MonsterManager[mkey]
                local mpos = monster._myPos
                local dist = cc.pGetDistance(apos, mpos)
                
                if dist < (attack.maxRange + monster._radius) and dist > attack.minRange then
                    --在距离满足条件的情况下，检测攻击角度是否满足
                    local angle = radNormalize(cc.pToAngleSelf(cc.pSub(mpos,apos)))
                    local afacing = radNormalize(attack.facing)
                    --如果怪物在角色的攻击范围之内，调用onCollide
                    if(afacing + attack.angle / 2) > angle and angle > (afacing- attack.angle/2) then
                        attack:onCollide(monster)
                    end
                end
            end
            
            --if heroes attack, then lets check monsters
            for hkey = HeroManager.last, HeroManager.first, -1 do
                --check distance first
                local hero = HeroManager[hkey]
                local hpos = hero._myPos
                local dist = cc.pGetDistance(getPosTable(attack), hpos)
                if dist < (attack.maxRange + hero._radius) and dist > attack.minRange then
                    --range test passed, now angle test
                    local angle = cc.pToAngleSelf(cc.pSub(hpos,getPosTable(attack)))
                    --如果是有效攻击，调用onCollide
                    if(attack.facing + attack.angle/2)>angle and angle > (attack.facing- attack.angle/2) then
                        attack:onCollide(hero)
                    end
                end
            end

            --这里需要加入 对道具的碰撞检测
            for pkey = PropManager.last, PropManager.first, -1 do
                local prop = PropManager[pkey]
                local ppos = prop._myPos
                local dist = cc.pGetDistance(apos, ppos)

                if dist < (attack.maxRange + prop._radius) and dist > attack.minRange then
                    --在距离满足条件的情况下，检测攻击角度是否满足
                    local angle = radNormalize(cc.pToAngleSelf(cc.pSub(ppos,apos)))
                    local afacing = radNormalize(attack.facing)
                    --如果怪物在角色的攻击范围之内，调用onCollide
                    if(afacing + attack.angle / 2) > angle and angle > (afacing- attack.angle/2) then
                        attack:onCollide(prop)
                    end
                end
            end
        elseif attack.mask == EnumRaceType.MONSTER then --如果是野怪发出攻击
            --if heroes attack, then lets check monsters
            for hkey = HeroManager.last, HeroManager.first, -1 do
                --check distance first
                local hero = HeroManager[hkey]
                local hpos = hero._myPos
                local dist = cc.pGetDistance(getPosTable(attack), hpos)
                if dist < (attack.maxRange + hero._radius) and dist > attack.minRange then
                    --range test passed, now angle test
                    local angle = cc.pToAngleSelf(cc.pSub(hpos,getPosTable(attack)))
                    --如果是有效攻击，调用onCollide
                    if(attack.facing + attack.angle/2)>angle and angle > (attack.facing- attack.angle/2) then
                        attack:onCollide(hero)
                    end
                end
            end
        end

        --根据duration判断超时
        attack.curDuration = attack.curDuration + dt
        if attack.curDuration > attack.duration then
            attack:onTimeOut() --移除攻击单位
            List.remove(AttackManager,val)
        else
            attack:onUpdate(dt)--根据speed更新位置
        end
    end
end

--声明基本的碰撞体，作为角色释放的攻击单位
BasicCollider = class("BasicCollider", function()
    local node = cc.Sprite3D:create()
    node:setCascadeColorEnabled(true)--跟随父节点级联变色
    return node
end)

--构造函数，每个角色的具体参数都在GlobalVariables.lua中配置
function BasicCollider:ctor()
    self.minRange = 0   --the min radius of the fan
    --这两个参数就可以决定了一个 "技能的作用区域",可以很方便得实现如"扇形"等攻击区域。这样攻击技能的生效不一定需要BasicCollider和目标“碰撞”才触发,只要敌人站在攻击区域就可以算打到了。
    self.maxRange = 150 --the max radius of the fan
    self.angle    = 90 --arc of attack, in radians，攻击角度，非常有用，关系到技能和攻击的作用范围
    
    self.knock    = 150 --default knock, knocks 150 units 
    self.mask     = 1   --1 is Heroes, 2 is enemy, 3 ??
    self.damage   = 100
    self.facing    = 0 --this is radians
    self.duration = 0 --持续时间
    self.curDuration = 0
    self.speed = 0 --traveling speed}
    self.criticalChance = 0
    --还可以增加一个属性maxTarget，来决定一个技能是单体吸收还是能够穿透目标，作用在多个目标上面。比如dota里 大牛“冲击波” 巫妖的“连环霜冻”等。
end


--callback when the collider has being solved by the attack manager, 
--make sure you delete it from node tree, if say you have an effect attached to the collider node
function BasicCollider:onTimeOut()
    self:removeFromParent()
end

function BasicCollider:playHitAudio()
    ccexp.AudioEngine:play2d(CommonAudios.hit, false,0.7)
end

function BasicCollider:hurtEffect(target)
    
    local hurtAction = cc.Animate:create(animationCache:getAnimation("hurtAnimation"))
    local hurtEffect = cc.BillBoard:create()
    hurtEffect:setScale(1.5)
    hurtEffect:runAction(cc.Sequence:create(hurtAction, cc.RemoveSelf:create()))
    hurtEffect:setPosition3D(cc.V3(0,0,50))
    target:addChild(hurtEffect)  
end

--攻击生效， 播放动画，并调用目标的hurt函数
function BasicCollider:onCollide(target)
    self:hurtEffect(target)
    self:playHitAudio()    
    target:hurt(self)
end

function BasicCollider:onUpdate()
    -- implement this function if this is a projectile
end

function BasicCollider:initData(pos, facing, attackInfo)
    copyTable(attackInfo, self)
    
    self.facing = facing or self.facing
    self:setPosition(pos)
    List.pushlast(AttackManager, self)
    currentLayer:addChild(self, -10)
end

function BasicCollider.create(pos, facing, attackInfo)
    local ret = BasicCollider.new()    
    ret:initData(pos,facing,attackInfo)
    return ret
end


KnightNormalAttack = class("KnightNormalAttack", function()
    return BasicCollider.new()
end)

function KnightNormalAttack.create(pos, facing, attackInfo, knight)
    local ret = KnightNormalAttack.new()
    ret:initData(pos,facing,attackInfo)
    ret.owner = knight
    return ret
end

function KnightNormalAttack:onTimeOut()
    self:removeFromParent()
end

MageNormalAttack = class("MageNormalAttack", function()
    return BasicCollider.new()
end)

function MageNormalAttack.create(pos,facing,attackInfo, target, owner)
    local ret = MageNormalAttack.new()
    ret:initData(pos,facing,attackInfo)
    ret._target = target
    ret.owner = owner
    
    ret.sp = cc.BillBoard:create("FX/FX.png", RECTS.iceBolt, 0)
    --ret.sp:setCamera(camera)
    ret.sp:setPosition3D(cc.V3(0,0,50))
    ret.sp:setScale(2)
    ret:addChild(ret.sp)
    
    local smoke = cc.ParticleSystemQuad:create(ParticleManager:getInstance():getPlistData("iceTrail"))
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("puff.png")
    smoke:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    smoke:setScale(2)
    ret:addChild(smoke)
    smoke:setRotation3D({x=90, y=0, z=0})
    smoke:setGlobalZOrder(0)
    smoke:setPositionZ(50)
    
    local pixi = cc.ParticleSystemQuad:create(ParticleManager:getInstance():getPlistData("pixi"))
    local pixif = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    pixi:setTextureWithRect(pixif:getTexture(), pixif:getRect())
    pixi:setScale(2)
    ret:addChild(pixi)
    pixi:setRotation3D({x=90, y=0, z=0})
    pixi:setGlobalZOrder(0)
    pixi:setPositionZ(50)
    
    ret.part1 = smoke
    ret.part2 = pixi
    return ret
end

function MageNormalAttack:onTimeOut()
    self.part1:stopSystem()
    self.part2:stopSystem()
    self:runAction(cc.Sequence:create(cc.DelayTime:create(1),cc.RemoveSelf:create()))
    
    local magic = cc.ParticleSystemQuad:create(ParticleManager:getInstance():getPlistData("magic"))
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    magic:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    magic:setScale(1.5)
    magic:setRotation3D({x=90, y=0, z=0})
    self:addChild(magic)
    magic:setGlobalZOrder(0)
    magic:setPositionZ(0)
    
    self.sp:setTextureRect(RECTS.iceSpike)
    self.sp:runAction(cc.FadeOut:create(1))
    self.sp:setScale(4)

end

function MageNormalAttack:playHitAudio()
    ccexp.AudioEngine:play2d(MageProperty.ice_normalAttackHit, false,1)
end

function MageNormalAttack:onCollide(target)

    self:hurtEffect(target)
    self:playHitAudio()    
    self.owner._angry = self.owner._angry + target:hurt(self)*0.3
    local anaryChange = {_name = MageValues._name, _angry = self.owner._angry, _angryMax = self.owner._angryMax}
    MessageDispatchCenter:dispatchMessage(MessageDispatchCenter.MessageType.ANGRY_CHANGE, anaryChange)
    --set cur duration to its max duration, so it will be removed when checking time out
    self.curDuration = self.duration+1
end

function MageNormalAttack:onUpdate(dt)
    local nextPos
    if self._target and self._target._isalive then
        local selfPos = getPosTable(self)
        local tpos = self._target._myPos
        local angle = cc.pToAngleSelf(cc.pSub(tpos,selfPos))
        nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,angle)
    else
        local selfPos = getPosTable(self)
        nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,self.facing)
    end
    self:setPosition(nextPos)
end


MageIceSpikes = class("MageIceSpikes", function()
    return BasicCollider.new()
end)

function MageIceSpikes:playHitAudio()
    ccexp.AudioEngine:play2d(MageProperty.ice_specialAttackHit, false,0.7)
end

function MageIceSpikes.create(pos, facing, attackInfo, owner)
    local ret = MageIceSpikes.new()
    ret:initData(pos,facing,attackInfo)
    ret.sp = cc.ShadowSprite:createWithSpriteFrameName("shadow.png")
    ret.sp:setGlobalZOrder(-ret:getPositionY()+FXZorder)
    ret.sp:setOpacity(100)
    ret.sp:setPosition3D(cc.V3(0,0,1))
    ret.sp:setScale(ret.maxRange/12)
    ret.sp:setGlobalZOrder(-1)
    ret:addChild(ret.sp)
    ret.owner = owner

    ---========
    --create 3 spikes
    local x = cc.Node:create()
    ret.spikes = x
    ret:addChild(x)
    for var=0, 10 do
        local rand = math.ceil(math.random()*3)
        local spike = cc.Sprite:createWithSpriteFrameName(string.format("iceSpike%d.png",rand))
        spike:setAnchorPoint(0.5,0)
        spike:setRotation3D(cc.V3(90,0,0))
        x:addChild(spike)
        if rand == 3 then
            spike:setScale(1.5)
        else
            spike:setScale(2)
        end
        spike:setOpacity(165)
        spike:setFlippedX(not(math.floor(math.random()*2)))
        spike:setPosition3D(cc.V3(math.random(-ret.maxRange/1.5, ret.maxRange/1.5),math.random(-ret.maxRange/1.5, ret.maxRange/1.5),1))
        spike:setGlobalZOrder(0)
        x:setScale(0)
        x:setPositionZ(-210)
    end
    x:runAction(cc.EaseBackOut:create(cc.MoveBy:create(0.3,cc.V3(0,0,200))))
    x:runAction(cc.EaseBounceOut:create(cc.ScaleTo:create(0.4, 1)))
    
    local magic = cc.BillboardParticleSystem:create(ParticleManager:getInstance():getPlistData("magic"))
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    magic:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    magic:setCamera(camera)
    magic:setScale(1.5)
    ret:addChild(magic)
    magic:setGlobalZOrder(-ret:getPositionY()*2+FXZorder)
    magic:setPositionZ(0)

    
    return ret
end

function MageIceSpikes:onTimeOut()
    self.spikes:setVisible(false)
    local puff = cc.BillboardParticleSystem:create(ParticleManager:getInstance():getPlistData("puffRing"))
    --local puff = cc.ParticleSystemQuad:create("FX/puffRing.plist")
    local puffFrame = cc.SpriteFrameCache:getInstance():getSpriteFrame("puff.png")
    puff:setTextureWithRect(puffFrame:getTexture(), puffFrame:getRect())
    puff:setCamera(camera)
    puff:setScale(3)
    self:addChild(puff)
    puff:setGlobalZOrder(-self:getPositionY()+FXZorder)
    puff:setPositionZ(20)
    
    local magic = cc.BillboardParticleSystem:create(ParticleManager:getInstance():getPlistData("magic"))
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    magic:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    magic:setCamera(camera)
    magic:setScale(1.5)
    self:addChild(magic)
    magic:setGlobalZOrder(-self:getPositionY()+FXZorder)
    magic:setPositionZ(0)
        
    self.sp:runAction(cc.FadeOut:create(1))
    self:runAction(cc.Sequence:create(cc.DelayTime:create(1),cc.RemoveSelf:create()))
end

function MageIceSpikes:playHitAudio()

end

function MageIceSpikes:onCollide(target)
    if self.curDOTTime > self.DOTTimer then
        self:hurtEffect(target)
        self:playHitAudio()    
        self.owner._angry = self.owner._angry + target:hurt(self)*0.1
        local anaryChange = {_name = MageValues._name, _angry = self.owner._angry, _angryMax = self.owner._angryMax}
        MessageDispatchCenter:dispatchMessage(MessageDispatchCenter.MessageType.ANGRY_CHANGE, anaryChange)
        self.DOTApplied = true
    end
end

function MageIceSpikes:onUpdate(dt)
-- implement this function if this is a projectile
    self.curDOTTime = self.curDOTTime + dt
    if self.DOTApplied then
        self.DOTApplied = false
        self.curDOTTime = 0
    end
end

ArcherNormalAttack = class("ArcherNormalAttack", function()
    return BasicCollider.new()
end)

function ArcherNormalAttack.create(pos,facing,attackInfo, owner)
    local ret = ArcherNormalAttack.new()
    ret:initData(pos,facing,attackInfo)
    ret.owner = owner
    
    ret.sp = Archer:createArrow()
    ret.sp:setRotation(RADIANS_TO_DEGREES(-facing)-90)
    ret:addChild(ret.sp)

    return ret
end

function ArcherNormalAttack:onTimeOut()
    self:runAction(cc.RemoveSelf:create())
end

function ArcherNormalAttack:onCollide(target)
    self:hurtEffect(target)
    self:playHitAudio()    
    self.owner._angry = self.owner._angry + target:hurt(self, true)*0.3
    local anaryChange = {_name = ArcherValues._name, _angry = self.owner._angry, _angryMax = self.owner._angryMax}
    MessageDispatchCenter:dispatchMessage(MessageDispatchCenter.MessageType.ANGRY_CHANGE, anaryChange)
    --set cur duration to its max duration, so it will be removed when checking time out
    self.curDuration = self.duration+1
end

function ArcherNormalAttack:onUpdate(dt)
    local selfPos = getPosTable(self)
    local nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,self.facing)
    self:setPosition(nextPos)
end

ArcherSpecialAttack = class("ArcherSpecialAttack", function()
    return BasicCollider.new()
end)

function ArcherSpecialAttack.create(pos,facing,attackInfo, owner)
    local ret = ArcherSpecialAttack.new()
    ret:initData(pos,facing,attackInfo)
    ret.owner = owner
    ret.sp = Archer:createArrow()
    ret.sp:setRotation(RADIANS_TO_DEGREES(-facing)-90)
    ret:addChild(ret.sp)
    
    return ret
end

function ArcherSpecialAttack:onTimeOut()
    self:runAction(cc.RemoveSelf:create())
end

function ArcherSpecialAttack:onCollide(target)
    if self.curDOTTime >= self.DOTTimer then
        self:hurtEffect(target)
        self:playHitAudio()    
        self.owner._angry = self.owner._angry + target:hurt(self, true)*0.3
        local anaryChange = {_name = ArcherValues._name, _angry = self.owner._angry, _angryMax = self.owner._angryMax}
        MessageDispatchCenter:dispatchMessage(MessageDispatchCenter.MessageType.ANGRY_CHANGE, anaryChange)
        self.DOTApplied = true
    end
end

function ArcherSpecialAttack:onUpdate(dt)
    local selfPos = getPosTable(self)
    local nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,self.facing)
    self:setPosition(nextPos)
    self.curDOTTime = self.curDOTTime + dt
    if self.DOTApplied then
        self.DOTApplied = false
        self.curDOTTime = 0
    end
end

Nova = class("nova", function()
    return BasicCollider.new()
end)

function Nova.create(pos, facing)
    local ret = Nova.new()
    ret:initData(pos, facing, BossValues.nova)
    
    ret.sp = cc.Sprite:createWithSpriteFrameName("nova1.png")
    ret.sp:setGlobalZOrder(-ret:getPositionY()+FXZorder)
    ret:addChild(ret.sp)
    ret.sp:setPosition(cc.V3(0,0,1))
    ret.sp:setScale(0)
    ret.sp:runAction(cc.EaseCircleActionOut:create(cc.ScaleTo:create(0.3, 3)))
    ret.sp:runAction(cc.FadeOut:create(0.7))
    return ret
end
function Nova:onCollide(target)
    if self.curDOTTime > self.DOTTimer then
        self:hurtEffect(target)
        self:playHitAudio()    
        self.DOTApplied = true
        target:hurt(self)
    end
end

function Nova:onUpdate(dt)
    -- implement this function if this is a projectile
    self.curDOTTime = self.curDOTTime + dt
    if self.DOTApplied then
        self.DOTApplied = false
        self.curDOTTime = 0
    end
end

function Nova:onTimeOut()
    self:runAction(cc.Sequence:create(cc.DelayTime:create(1),cc.RemoveSelf:create()))
end
DragonAttack = class("DragonAttack", function()
    return BasicCollider.new()
end)

function DragonAttack.create(pos,facing,attackInfo)
    local ret = DragonAttack.new()
    ret:initData(pos,facing,attackInfo)

    ret.sp = cc.BillBoard:create("FX/FX.png", RECTS.fireBall)
    ret.sp:setPosition3D(cc.V3(0,0,48))
    ret.sp:setScale(1.7)
    ret:addChild(ret.sp)

    return ret
end

function DragonAttack:onTimeOut()
    self:runAction(cc.Sequence:create(cc.DelayTime:create(0.5),cc.RemoveSelf:create()))

    local magic = cc.ParticleSystemQuad:create(ParticleManager:getInstance():getPlistData("magic"))
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    magic:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    magic:setScale(1.5)
    magic:setRotation3D({x=90, y=0, z=0})
    self:addChild(magic)
    magic:setGlobalZOrder(-self:getPositionY()*2+FXZorder)
    magic:setPositionZ(0)
    magic:setEndColor({r=1,g=0.5,b=0})

    local fireballAction = cc.Animate:create(animationCache:getAnimation("fireBallAnim"))
    self.sp:runAction(fireballAction)
    self.sp:setScale(2)
    
    
end

function DragonAttack:playHitAudio()
    ccexp.AudioEngine:play2d(MonsterDragonValues.fireHit, false,0.6)    
end

function DragonAttack:onCollide(target)
    self:hurtEffect(target)
    self:playHitAudio()    
    target:hurt(self)
    --set cur duration to its max duration, so it will be removed when checking time out
    self.curDuration = self.duration+1
end

function DragonAttack:onUpdate(dt)
    local selfPos = getPosTable(self)
    local nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,self.facing)
    self:setPosition(nextPos)
end

BossNormal = class("BossNormal", function()
    return BasicCollider.new()
end)

function BossNormal.create(pos,facing,attackInfo)
    local ret = BossNormal.new()
    ret:initData(pos,facing,attackInfo)

    ret.sp = cc.BillBoard:create("FX/FX.png", RECTS.fireBall)
    ret.sp:setPosition3D(cc.V3(0,0,48))
    ret.sp:setScale(1.7)
    ret:addChild(ret.sp)

    return ret
end

function BossNormal:onTimeOut()
    self:runAction(cc.Sequence:create(cc.DelayTime:create(0.5),cc.RemoveSelf:create()))

    local magic = cc.ParticleSystemQuad:create(ParticleManager:getInstance():getPlistData("magic"))
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    magic:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    magic:setScale(1.5)
    magic:setRotation3D({x=90, y=0, z=0})
    self:addChild(magic)
    magic:setGlobalZOrder(-self:getPositionY()*2+FXZorder)
    magic:setPositionZ(0)
    magic:setEndColor({r=1,g=0.5,b=0})

    local fireballAction = cc.Animate:create(animationCache:getAnimation("fireBallAnim"))
    self.sp:runAction(fireballAction)
    self.sp:setScale(2)
    
    Nova.create(getPosTable(self), self._curFacing)
end

function BossNormal:playHitAudio()
    ccexp.AudioEngine:play2d(MonsterDragonValues.fireHit, false,0.6)    
end

function BossNormal:onCollide(target)
    --set cur duration to its max duration, so it will be removed when checking time out
    self.curDuration = self.duration+1
end

function BossNormal:onUpdate(dt)
    local selfPos = getPosTable(self)
    local nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,self.facing)
    self:setPosition(nextPos)
end

BossSuper = class("BossSuper", function()
    return BasicCollider.new()
end)

function BossSuper.create(pos,facing,attackInfo)
    local ret = BossSuper.new()
    ret:initData(pos,facing,attackInfo)

    ret.sp = cc.BillBoard:create("FX/FX.png", RECTS.fireBall)
    ret.sp:setPosition3D(cc.V3(0,0,48))
    ret.sp:setScale(1.7)
    ret:addChild(ret.sp)

    return ret
end

function BossSuper:onTimeOut()
    self:runAction(cc.Sequence:create(cc.DelayTime:create(0.5),cc.RemoveSelf:create()))

    local magic = cc.ParticleSystemQuad:create(ParticleManager:getInstance():getPlistData("magic"))
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    magic:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    magic:setScale(1.5)
    magic:setRotation3D({x=90, y=0, z=0})
    self:addChild(magic)
    magic:setGlobalZOrder(-self:getPositionY()*2+FXZorder)
    magic:setPositionZ(0)
    magic:setEndColor({r=1,g=0.5,b=0})

    local fireballAction = cc.Animate:create(animationCache:getAnimation("fireBallAnim"))
    self.sp:runAction(fireballAction)
    self.sp:setScale(2)

    Nova.create(getPosTable(self), self._curFacing)
end

function BossSuper:playHitAudio()
    ccexp.AudioEngine:play2d(MonsterDragonValues.fireHit, false,0.6)    
end

function BossSuper:onCollide(target)
    --set cur duration to its max duration, so it will be removed when checking time out
    self.curDuration = self.duration+1
end

function BossSuper:onUpdate(dt)
    local selfPos = getPosTable(self)
    local nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,self.facing)
    self:setPosition(nextPos)
end


HookAttack = class("HookAttack", function()
	return BasicCollider.new()
end)

function HookAttack.create(pos,facing,attackInfo, target, owner)
    local ret = HookAttack.new()
    ret:initData(pos,facing,attackInfo)
    ret._target = target
    ret.owner = owner
    
	ret.sp = cc.Sprite3D:create("minigame/maoRedoUv.c3b")--("minigame/test-weapon/miaolian.c3b")
    --ret.sp:setCamera(camera)
    ret.sp:setPosition3D(cc.V3(0,0,50))
    ret.sp:setScale(7,42)
	ret.sp:setRotation3D(cc.V3(0,0,180+270 - facing * 180 / 3.14))
	
    ret:addChild(ret.sp)
	ret._radius = 20
	ret.startPos = pos;
	ret.state = "ATTACK"
	ret.hasTarget = false
	-- 链条的位置
    ret.chainPos = pos
	ret.chainList = List.new()
    return ret
end

function HookAttack:onTimeOut()
	List.removeObj(AttackManager, self)
    self:removeFromParent()
	--uiLayer.label:setString("HookTimeOut")
end

function HookAttack:playHitAudio()
    ccexp.AudioEngine:play2d(MageProperty.ice_normalAttackHit, false,1)
end

function HookAttack:onCollide(target)
	-- if(self.state == "ATTACK") then
		-- 测试钩子返回过程中是否可以钩人以及碰撞
		-- return
	-- end
    if target == self.owner then
        return
    end
    
	if(target._isalive == false) then
		return
	end
	if(self.hasTarget == true) then
		--如果已经发生了碰撞，则不再生效
		return
	else
		--钩中
		target:hook(self)
		--已钩到人
		self.hasTarget = true
		print("Peng!")
		--返回
		self.state = "BACK"
	end
end

function HookAttack:onUpdate(dt)
	if self.state == "ATTACK" then
		--uiLayer.label:setString("HookAttack")
		local nextPos
		local selfPos = getPosTable(self)
		nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,self.facing)
		self:setPosition(nextPos)

		if cc.pGetDistance(self.chainPos, selfPos) >= 30 then
			local sprite = cc.Sprite3D:create("minigame/maolianRedoUv.c3b")
			sprite:setPosition3D(cc.V3(selfPos.x,selfPos.y,50))
			sprite:setScale(0.5)
			sprite:setRotation3D(cc.V3(90,0,90+360 - self.facing * 180 / 3.14))
			currentLayer:addChild(sprite)			
			List.pushlast(self.chainList, sprite)
			--print("ATTACK",List.getSize(self.chainList))
			self.chainPos = selfPos
		end
		if cc.pGetDistance(self.startPos, selfPos) >= self.attackLength then
			self.chainPos = selfPos
			-- local sprite = List.poplast(self.chainList)
			-- sprite:removeFromParent()
			self.state = "BACK"
		end
	elseif self.state == "BACK" then
		--uiLayer.label:setString("HookBack")
		local selfPos = getPosTable(self)
		-- if sp ~= nil then
			-- sp:onTimeOut()
		-- end
		local nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed2*dt, y=0},selfPos),selfPos,self.facing)
		local distance = cc.pGetDistance(self.startPos, selfPos)
		for i=1, List.getSize(self.chainList) do
			-- 获取列表中最后的点，如果这个点到起点的距离没有当前点到起点的距离大，就把他放回去
			-- 如果比之大，则删除这个链条
			local sprite = List.poplast(self.chainList)
			if cc.pGetDistance(cc.p(sprite:getPositionX(),sprite:getPositionY()),self.startPos)+30 <= distance then
				List.pushlast(self.chainList,sprite)
				break
			end
			sprite:removeFromParent()
		end
		self.chainPos = selfPos
		-- 判断钩子是否回到原地
		--if (selfPos.x-self.startPos.x)*(nextPos.x-self.startPos.x)<=0 then
		if cc.pGetDistance(self.startPos, selfPos) <= 100 then
			for index=self.chainList.first, List.getSize(self.chainList) do	
				if self.chainList[index]  then
					self.chainList[index]:removeFromParent()
				end
			end
			self:onTimeOut()
			return
		end
		self:setPosition(nextPos)
	end
end

return AttackManager
