--[[
-- object for communication between entities and for communication
-- between entities and the game state
-- entities can send signals to all other entities, each signal
-- has a sender entity id and destination entity id but all entities can recieve the
-- signal and respond to it. each signal has a payload and properties
--
-- if sender/destination id is not required/unspecified use -1
--
-- entities handle signals before their update functions are called
--
-- common signals are in src/sig
--
-- the purpose of signals is to allow for entities to perform actions to other entities
-- without having to care about whats at the other end, for example the player entity
-- can send an interact signal at an entity and doesn't have to worry about whether or
-- not that entity can be interacted with or what it should do when interacted with, that
-- behavious is handled by the other entities signal handler
--
--]]

require "props/sigprops"

Signal = {}
Signal.__index = Signal

-- STRING, INT, INT, TABLE, FLAGS
function Signal:new(signalprops)
	local this = {
		props = SigPropPrototype(signalprops) 
	}
	setmetatable(this, Signal)
	return this
end

function Signal:GetProp(k)
	return self.props[k]
end

function Signal:DebugText()
	return (self.props.sig_debugtext or "") ..
	       "(" .. self.props.sig_type .. "," .. self.props.sig_sender .. "," .. self.props.sig_dest .. ")"
end
Signal.__tostring = function (sig)
	return sig:DebugText()
end

IRIS_SIGNALS = {

}

function IRIS_SIGNAL_REGISTERED(name)
	return IRIS_SIGNALS[name] ~= nil
end

function IRIS_REGISTER_SIGNAL(signal_prototype)
	IRIS_SIGNALS[signal_prototype.props.sig_type] = signal_prototype
end

function IrisCreateSignal(name, ent, payload, destent)
	local sigdesc = IRIS_SIGNALS[name]
	if IRIS_SIGNALS[name] then
		local sigprops = sigdesc.props
		local sigpayload = sigdesc.payload
		if payload then
			for i,v in pairs(payload) do
				sigpayload[i] = v
			end
		end
		sigprops.signal_payload = sigpayload

		local sig = Signal:new(sigprops)

		if ent then
			sig.props.sig_sender = ent.props.ent_id
		end
		if destent then
			sig.props.sig_dest = destent.props.ent_id
		end

		return sig
	end

	print("IrisCreateSignal: " .. name .. " is not a registered signal")
end
