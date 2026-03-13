local Directory = {}

-- Services
Directory.ReplicatedStorage = game:GetService("ReplicatedStorage")
Directory.ServerScriptService = game:GetService("ServerScriptService")
Directory.ServerStorage = game:GetService("ServerStorage")
Directory.PlayerService = game:GetService("Players")
Directory.TweenService = game:GetService("TweenService")
Directory.ContentProvider = game:GetService("ContentProvider")
Directory.MarketPlaceService = game:GetService("MarketplaceService")
Directory.StarterGui = game:GetService("StarterGui")
Directory.SoundService = game:GetService("SoundService")
Directory.GroupService = game:GetService("GroupService")
Directory.AvatarService = game:GetService("AvatarEditorService")
Directory.RunService = game:GetService("RunService")
Directory.UserInputService = game:GetService("UserInputService")

-- Folders
Directory.SoundsFolder = Directory.SoundService:WaitForChild("Sounds")
Directory.MusicFolder = Directory.SoundsFolder:WaitForChild("Music")
Directory.SFXFolder = Directory.SoundsFolder:WaitForChild("SFX")
Directory.Modules = Directory.ServerStorage:WaitForChild("Modules")
Directory.Events = Directory.ReplicatedStorage:WaitForChild("Events")
Directory.Templates = Directory.ServerStorage:WaitForChild("Templates")
Directory.MapTemplateFolder = Directory.Templates:WaitForChild("Map")
Directory.DeathSFXFolder = Directory.SFXFolder:WaitForChild("DeathFX")

-- Events
Directory.ToggleAFK = Directory.Events:WaitForChild("ToggleAFK")
Directory.SFXEvent = Directory.Events:WaitForChild("SFXEvent")
Directory.MusicEvent = Directory.Events:WaitForChild("MusicEvent")
Directory.GachaEvent = Directory.Events:WaitForChild("GachaUI")
Directory.EmoteEvent = Directory.Events:WaitForChild("EmoteEvent")
Directory.ProductEvent = Directory.Events:WaitForChild("ProductEvent")
Directory.TimerEvent = Directory.Events:WaitForChild("TimerEvent")
Directory.InitEvent = Directory.Events:WaitForChild("InitEvent")
Directory.ChestEvent = Directory.Events:WaitForChild("ChestEvent")    
Directory.DailyEvent = Directory.Events:WaitForChild("DailyEvent")
Directory.NotificationEvent = Directory.Events:WaitForChild("NotificationEvent")
Directory.ProductEvent = Directory.Events:WaitForChild("ProductEvent")
Directory.PromptEvent = Directory.Events:WaitForChild("PromptEvent")
Directory.ButtonEvent = Directory.Events:WaitForChild("ButtonEvent")
Directory.DailyEvent = Directory.Events:WaitForChild("DailyEvent")
Directory.EmoteRequest = Directory.Events:WaitForChild("EmoteRequest")
Directory.CurrencyEvent = Directory.Events:WaitForChild("CurrencyEvent")
Directory.RoundEvent = Directory.Events:WaitForChild("RoundEvent")
Directory.SaveEmoteSlot = Directory.Events:WaitForChild("SaveEmoteSlot")
Directory.CaseRequest = Directory.Events:WaitForChild("CaseRequest")
Directory.EquipDeath = Directory.Events:WaitForChild("EquipDeath")
Directory.DeathEvent = Directory.Events:WaitForChild("DeathEvent")
Directory.EquipCount = Directory.Events:WaitForChild("EquipCount")
Directory.CountEvent = Directory.Events:WaitForChild("CountEvent")
Directory.CaseOpen = Directory.Events:WaitForChild("CaseOpen")

Directory.VerifyEvent = Directory.Events:WaitForChild("VerifyEvent")  -- Verifies Item Ownership
Directory.InventoryEvent = Directory.Events:WaitForChild("InventoryEvent") -- Sends Inventory Data

-- Tweens
Directory.HoverInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)


return Directory
