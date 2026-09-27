--!strict
local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({}, Signal))

function Signal.new(): Signal
	local self = setmetatable({}, Signal)
	self._bindable = Instance.new("BindableEvent")
	return self
end

function Signal.Fire(self: Signal, ...: any)
	self._bindable:Fire(...)
end

function Signal.Connect(self: Signal, fn: (...any) -> ()): RBXScriptConnection
	return self._bindable.Event:Connect(fn)
end

function Signal.Wait(self: Signal): ...any
	return self._bindable.Event:Wait()
end

function Signal.Destroy(self: Signal)
	self._bindable:Destroy()
end

return Signal
